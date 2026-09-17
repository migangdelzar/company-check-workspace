# Architecture Documentation Refresh Implementation Plan

> **Completed historical plan.** This plan records the earlier refresh that
> aligned the workspace docs with the layered backend. Current architecture
> guidance lives in `docs/architecture/` and `docs/adr/`; obsolete package names
> in the checked-off steps describe migration work, not the current source tree.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring ADRs, architecture pages, Mermaid diagrams, and README architecture text into agreement with the current layered Spring Boot backend and unchanged Bun provider/runtime topologies.

**Architecture:** Keep the existing documentation set and links. Replace stale hexagonal package vocabulary with the checked-out layers (`config`, `controller`, `service`, `repository`, `client`, `mapper`, `exception`), and make diagrams trace actual classes and runtime dependencies. Preserve the existing PostgreSQL-first, profile-specific coordination, provider fallback, Compose, and observability decisions.

**Tech Stack:** Markdown, Mermaid, Spring Boot 4.1.1, Java 25, Spring JDBC `JdbcClient`, Spring Data Redis, Caffeine, Resilience4j, Apache HttpClient 5, Bun/Fastify, Docker Compose.

## Global Constraints

- Preserve existing HTTP API, provider contracts, persistence behavior, resilience behavior, coordination behavior, scheduled expiration, observability, and native-image support.
- No source-code, Compose, OpenAPI, or submodule changes.
- `company-check-service` uses `config`, `controller`, `service`, `repository`, `client`, `mapper`, and `exception`; no production classes remain under `adapter`, `application`, or `domain`.
- PostgreSQL remains authoritative; Caffeine is local cache; Redis is used for distributed coordination/cache/rate limits only.
- Preserve unrelated pre-existing working-tree changes.

---

### Task 1: Update ADR index and architecture decision language

**Files:**
- Modify: `docs/adr/README.md`
- Modify: `docs/adr/0001-hexagonal-modulith.md`
- Modify: `docs/adr/0002-postgresql-jdbcclient-and-hikari.md`
- Modify: `docs/adr/0003-redis-for-distributed-coordination.md`
- Modify: `docs/adr/0004-provider-http-pools-and-resilience.md`
- Modify: `docs/adr/0005-filters-observations-and-aop-boundaries.md`
- Modify: `docs/adr/0006-virtual-threads-and-bounded-resources.md`
- Modify: `docs/adr/0007-gradle-paketo-and-immutable-compose.md`
- Modify: `docs/adr/0008-testcontainers-docker-context.md`

**Interfaces:**
- Produces ADR terminology consistent with the actual service package tree and current configuration class names.

- [x] **Step 1: Rewrite ADR 0001 in place.**

  Record the current conventional layered Spring Boot Modulith boundary, explain that the filename is retained for link stability, and remove claims that the implementation uses `domain`, `application`, `adapter/in`, or `adapter/out` packages.

- [x] **Step 2: Correct stale implementation references in ADRs 0002–0008.**

  Keep their accepted decisions, but name actual implementations such as `JdbcVerificationRepository`, `CoordinationRepository`, `ProviderClient`, `InboundRateLimitFilter`, `ObservedAspect`, and `config/*` where the current source supports those details.

- [x] **Step 3: Update the ADR index summary.**

  Change the ADR 0001 row to describe layered Modulith boundaries while preserving all document links and statuses.

- [x] **Step 4: Search the ADR set for obsolete package vocabulary.**

  Run:

  ```sh
  rg --no-index -n 'adapter\.in|adapter\.out|application\.port|application\.service|domain package|hexagonal ports' docs/adr
  ```

  Expected: no stale implementation claims remain; historical rationale may mention the rejected hexagonal alternative only when clearly labeled as rejected/history.

### Task 2: Refresh architecture reference pages and all Mermaid diagrams

**Files:**
- Modify: `docs/architecture/README.md`
- Modify: `docs/architecture/overview.md`
- Modify: `docs/architecture/runtime-architecture.md`
- Modify: `docs/architecture/request-flow.md`
- Modify: `docs/architecture/expiration-flow.md`
- Modify: `docs/architecture/resilience.md`
- Modify: `docs/architecture/deployment.md`
- Modify: `docs/architecture/startup.md`
- Modify: `docs/architecture/testing.md`

**Interfaces:**
- Produces architecture pages that name current service classes and packages, while retaining public routes, profile behavior, resource bounds, and runtime topology.

- [x] **Step 1: Update the architecture index and overview.**

  Describe the layered backend and separate provider simulator. Add the real layer ownership and explain that `config` wires implementations while `mapper` and `exception` cross-cut layer boundaries deliberately.

- [x] **Step 2: Replace the runtime layer diagram and package table.**

  Diagram `config -> controller -> service -> repository/client`, with `mapper` and `exception` shown as supporting boundaries. Replace all `application`, `domain`, `adapter.*`, and `configuration.*` package claims with actual paths and class responsibilities.

- [x] **Step 3: Update request, recovery, provider, and expiration flows.**

  Rename `StartVerificationService` to `VerificationService`, `ProviderResolutionService` to `ProviderService`, and show `VerificationStoreService`, `VerificationRecoveryService`, `JdbcVerificationRepository`, and `CoordinationRepository` where they participate. Keep the exact endpoint paths and failure semantics.

- [x] **Step 4: Update runtime/build/deployment/observability diagrams.**

  Ensure every Mermaid block reflects the Compose files: base backend/providers/PostgreSQL, single-node local coordination, distributed Redis and scaled backend replicas, optional Locust, and the Prometheus/Alloy/Tempo/Loki/Grafana overlay.

- [x] **Step 5: Update testing/startup/resilience prose.**

  Keep commands and current bounds accurate. Clarify that architecture tests enforce layered boundaries and that provider DTOs, repository entities, and controller DTOs do not cross their intended layers.

### Task 3: Align top-level README architecture wording

**Files:**
- Modify: `README.md`

**Interfaces:**
- Produces README architecture summaries that link to the refreshed docs without changing setup commands or API examples.

- [x] **Step 1: Replace stale layer terminology.**

  Update architecture-related sentences to identify `VerificationService`, `ProviderService`, PostgreSQL persistence, profile-specific coordination, and the separate provider simulator.

- [x] **Step 2: Check README links and commands remain unchanged.**

  Run:

  ```sh
  rg --no-index -n 'docs/architecture|docs/adr|backend-service|verifications|mise run|gradlew|bun run' README.md
  ```

  Expected: all existing links, endpoints, and commands remain present.

### Task 4: Verify documentation consistency

**Files:**
- Modify: `tasks/todo.md`

- [x] **Step 1: Search all scoped docs for stale references.**

  Run:

  ```sh
  rg --no-index -n 'StartVerificationService|ProviderResolutionService|adapter\.in|adapter\.out|application\.port|application\.service|configuration\.|domain/' docs/adr docs/architecture README.md
  ```

  Expected: no references to removed production packages or removed service class names. Historical ADR text must distinguish rejected alternatives from the current design.

- [x] **Step 2: Validate Mermaid fences and current component names.**

  Run:

  ```sh
  awk '/```mermaid/{open++} /^```$/{if (open > 0) open--} END {if (open != 0) exit 1}' docs/adr/*.md docs/architecture/*.md
  rg --no-index -n '```mermaid|VerificationService|ProviderService|JdbcVerificationRepository|CoordinationRepository|free-provider|premium-provider|Redis|Prometheus|Grafana Alloy' docs/architecture
  ```

  Expected: balanced Mermaid fences and current components represented in the architecture set.

- [x] **Step 3: Validate formatting and Compose syntax when available.**

  Run:

  ```sh
  git diff --check
  docker compose -f compose.yaml -f compose.single.yaml config
  docker compose -f compose.yaml -f compose.distributed.yaml config
  ```

  Expected: no whitespace errors; both Compose merges render successfully. If Docker is unavailable, record that exact limitation in the final report.

- [x] **Step 4: Update the checklist with results.**

  Mark completed tasks in `tasks/todo.md` and add a Results section listing changed doc groups and verification outcomes.

- [x] **Step 5: Commit the documentation refresh.**

  ```sh
  git add README.md docs/adr docs/architecture tasks/todo.md
  git commit -m "docs: align architecture references with layered backend"
  ```
