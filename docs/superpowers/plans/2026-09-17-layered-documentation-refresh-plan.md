# Layered Architecture Documentation Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align every relevant Markdown file under `docs/` with the checked-out conventional layered Spring Boot backend, current runtime workflows, ADRs, diagrams, and validation guidance.

**Architecture:** Use the source tree and Compose/configuration files as the source of truth. Update current ADRs and architecture pages to describe `config`, `controller`, `service`, `repository`, `client`, `mapper`, `exception`, and `util`; retain historical design intent while clearly labeling superseded proposals. Prepare the PR title/body as a final handoff artifact without changing remote PR metadata.

**Tech Stack:** Markdown, Mermaid, Spring Boot 4.1.1, Java 25, Spring JDBC `JdbcClient`, Spring Data Redis, Caffeine, Resilience4j, Apache HttpClient 5, Bun/Fastify, Docker Compose.

## Global Constraints

- Modify Markdown files under `docs/` only.
- Do not change Java, TypeScript, Compose, OpenAPI, Gradle, or workflow YAML files.
- Preserve existing ADR filenames and links.
- `company-check-service` uses `config`, `controller`, `service`, `repository`, `client`, `mapper`, `exception`, and `util`; no production classes remain under the old `adapter`, `application`, or `domain` package tree.
- PostgreSQL remains authoritative; Caffeine is local cache; Redis is used for distributed coordination, cache, leases, and rate limits only in distributed mode.
- FREE is attempted before PREMIUM fallback; provider, API, persistence, Compose, and observability behavior remain unchanged.
- Preserve unrelated pre-existing working-tree changes, including the dirty `company-check-service` submodule.
- Historical specs and plans retain their original intent and are labeled when they describe superseded architecture.

---

### Task 1: Update ADRs and documentation indexes

**Files:**
- Modify: `docs/README.md`
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
- Consumes: `company-check-service/src/main/java/com/incode/verification/**`, current Gradle/Compose configuration, and the existing ADR decisions.
- Produces: ADR and index prose that names current layers and representative classes without changing accepted technical decisions.

- [ ] **Step 1: Compare every ADR claim with the current source tree.**

  Check these concrete implementations before editing: `config/*`, `controller/InboundRateLimitFilter.java`, `controller/VerificationExpirationScheduler.java`, `service/VerificationService.java`, `service/ProviderService.java`, `repository/JdbcVerificationRepository.java`, `repository/CoordinationRepository.java`, `repository/coordination/*`, `repository/ratelimit/*`, `client/ProviderClient.java`, `mapper/*`, and `exception/handler/GlobalExceptionHandler.java`.

- [ ] **Step 2: Rewrite ADR 0001 in place.**

  Keep `0001-hexagonal-modulith.md` for link stability. State that the accepted implementation is a conventional layered Spring Boot Modulith with `config`, `controller`, `service`, `repository`, `client`, `mapper`, and `exception`; retain the rejected hexagonal design only as historical rationale.

- [ ] **Step 3: Correct ADRs 0002–0008 without changing their decisions.**

  Use `JdbcVerificationRepository`, `CoordinationRepository`, `ProviderClient`, `InboundRateLimitFilter`, `ObservedAspect`, `config.ObservabilityConfiguration`, Gradle `build-logic`, and explicit Testcontainers properties only where supported by source/configuration. Replace any old package claims with the current package paths.

- [ ] **Step 4: Update both indexes.**

  Ensure `docs/README.md` points to all current architecture and ADR references, and `docs/adr/README.md` describes ADR 0001 as layered while preserving every filename and status.

- [ ] **Step 5: Run the ADR terminology check.**

  Run:

  ```sh
  rg --no-index -n -i -e 'adapter\.in|adapter\.out|application\.port|application\.service|com\.incode\.verification\.configuration|StartVerificationService|ProviderResolutionService' docs/adr docs/README.md
  ```

  Expected: no active implementation claims remain. Any retained match must be inside an explicitly labeled rejected or historical explanation.

- [ ] **Step 6: Commit only this task’s Markdown files.**

  ```sh
  git add docs/README.md docs/adr
  git commit -m "docs: align ADRs with layered backend"
  ```

### Task 2: Refresh architecture diagrams and runtime workflows

**Files:**
- Modify: `docs/architecture/README.md`
- Modify: `docs/architecture/overview.md`
- Modify: `docs/architecture/runtime-architecture.md`
- Modify: `docs/architecture/request-flow.md`
- Modify: `docs/architecture/resilience.md`
- Modify: `docs/architecture/expiration-flow.md`
- Modify: `docs/architecture/deployment.md`

**Interfaces:**
- Consumes: current Java package/class tree, `compose.yaml`, `compose.single.yaml`, `compose.distributed.yaml`, `compose.observability.yaml`, and `application*.yml`.
- Produces: Mermaid diagrams and prose that show the actual layered boundaries and unchanged runtime semantics.

- [ ] **Step 1: Refresh the architecture index and overview.**

  Describe the backend as one layered Modulith. Use the layer table `config → controller → service → repository/client`, with `mapper` and `exception` as explicit supporting boundaries and the Bun/Fastify provider as a separate deployable.

- [ ] **Step 2: Refresh the runtime architecture page.**

  Replace any legacy package tree with actual package paths. Name representative classes: `VerificationService`, `ProviderService`, `VerificationStoreService`, `VerificationRecoveryService`, `ExpirationService`, `JdbcVerificationRepository`, `CoordinationRepository`, `ProviderClient`, `InboundRateLimitFilter`, and `GlobalExceptionHandler`.

- [ ] **Step 3: Refresh the request and expiration diagrams.**

  Show `GET /backend-service` entering `InboundRateLimitFilter`, `BackendServiceController`, and `VerificationService`; show PostgreSQL lookup/claim/completion, coordination, `ProviderService` with FREE→PREMIUM fallback, and post-commit cache publication. Show retrieval as read-only. Show `VerificationExpirationScheduler` invoking `ExpirationService`, local/Redis lease ownership, and bounded JDBC expiration batches.

- [ ] **Step 4: Refresh resilience and deployment diagrams.**

  Show local Resilience4j versus distributed Redis rate limiting, the shared Apache HttpClient 5 pool, provider retry/circuit/rate/bulkhead ordering, PostgreSQL authority, Caffeine local cache, Redis distributed state, single-node and distributed Compose layouts, and the optional Prometheus/Alloy/Tempo/Loki/Grafana overlay.

- [ ] **Step 5: Validate all Mermaid blocks in the edited pages.**

  Run:

  ```sh
  awk '/```mermaid/{open++} /^```$/{if (open > 0) open--} END {if (open != 0) exit 1}' docs/architecture/*.md
  rg --no-index -n -e 'VerificationService|ProviderService|VerificationStoreService|VerificationRecoveryService|JdbcVerificationRepository|CoordinationRepository|ProviderClient|free-provider|premium-provider|Redis|Prometheus|Grafana Alloy' docs/architecture
  ```

  Expected: balanced fences and current classes/components represented in the architecture set.

- [ ] **Step 6: Commit only this task’s Markdown files.**

  ```sh
  git add docs/architecture/README.md docs/architecture/overview.md docs/architecture/runtime-architecture.md docs/architecture/request-flow.md docs/architecture/resilience.md docs/architecture/expiration-flow.md docs/architecture/deployment.md
  git commit -m "docs: refresh layered architecture diagrams"
  ```

### Task 3: Align startup, testing, performance, and supporting guidance

**Files:**
- Modify: `docs/architecture/startup.md`
- Modify: `docs/architecture/testing.md`

**Interfaces:**
- Consumes: `README.md`, `mise.toml`, Gradle tasks/convention plugins, performance runner, `.github/actions/compose-e2e/action.yml`, and current Compose overlays.
- Produces: current setup, test, performance, and validation guidance consistent with the layered service and existing commands.

- [ ] **Step 1: Verify startup commands against Compose and `mise.toml`.**

  Preserve valid image-build, single-node, distributed, observability, health-check, API-smoke, and shutdown commands. Correct only stale package, profile, service-name, or topology descriptions.

- [ ] **Step 2: Verify testing and performance guidance against Gradle and CI.**

  Keep `fastCheck`, `qualityGate`, integration/contract/E2E descriptions, Testcontainers Docker-context guidance, Locust defaults, immutable image requirements, and security/validation workflow summaries aligned with the actual build files and workflow YAML.

- [ ] **Step 3: Check documentation cross-links.**

  Confirm every link in `docs/README.md`, `docs/architecture/README.md`, and the edited pages resolves to an existing workspace path. For local Markdown links, run:

  ```sh
  ruby -e 'require "pathname"; bad=[]; Dir["docs/**/*.md"].each { |file| text=File.read(file); text.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each { |link| next if link.start_with?("http://", "https://", "#", "mailto:"); target=link.split("#", 2).first; next if target.empty?; path=Pathname.new(file).dirname.join(target); bad << "#{file}: #{link}" unless path.exist? } }; abort bad.join("\n") unless bad.empty?'
  ```

  Expected: exit 0 with no output.

- [ ] **Step 4: Commit only changed Markdown files from this task.**

  ```sh
  git add docs/architecture/startup.md docs/architecture/testing.md
  git diff --cached --name-only
  git commit -m "docs: align startup and validation guidance"
  ```

### Task 4: Label historical architecture records without rewriting history

**Files:**
- Modify: `docs/superpowers/specs/2026-09-16-architectural-modernization-design.md`
- Modify: `docs/superpowers/specs/2026-09-17-architecture-docs-design.md`
- Modify: `docs/superpowers/plans/2026-09-17-architecture-docs-refresh-plan.md`
- Do not modify: `docs/superpowers/specs/2026-09-17-layered-documentation-refresh-design.md`
- Do not modify: `docs/superpowers/specs/2026-09-17-contract-and-e2e-coverage-design.md`
- Do not modify: `docs/superpowers/specs/2026-09-17-observability-compose-design.md`
- Do not modify: `docs/superpowers/specs/2026-09-17-validation-security-pipelines-design.md`

**Interfaces:**
- Consumes: the approved layered refresh spec and the historical status of each design/plan.
- Produces: clear separation between current architecture guidance and historical migration material.

- [ ] **Step 1: Mark the pre-layered modernization design as historical.**

  Add a concise opening note stating that the document is a superseded proposal retained for historical context; its `adapter`, `application`, and `domain` package names describe the proposal at that date, not the checked-out implementation.

- [ ] **Step 2: Mark the previous architecture-doc refresh records as completed historical records.**

  Add status wording to the earlier design/plan stating that the layered refresh was delivered in the current architecture pages and ADRs. Do not rewrite their original task descriptions or obsolete search examples.

- [ ] **Step 3: Check historical wording is unambiguous.**

  Run:

  ```sh
  rg --no-index -n -i -e 'historical|superseded|current implementation|checked-out implementation' docs/superpowers/specs/2026-09-16-architectural-modernization-design.md docs/superpowers/specs/2026-09-17-architecture-docs-design.md docs/superpowers/plans/2026-09-17-architecture-docs-refresh-plan.md
  ```

  Expected: each retained obsolete architecture term is surrounded by wording that identifies it as historical, proposed, rejected, or a completed migration step.

- [ ] **Step 4: Commit only the historical-record changes.**

  ```sh
  git add docs/superpowers/specs/2026-09-16-architectural-modernization-design.md docs/superpowers/specs/2026-09-17-architecture-docs-design.md docs/superpowers/plans/2026-09-17-architecture-docs-refresh-plan.md
  git commit -m "docs: label superseded architecture records"
  ```

### Task 5: Run the complete documentation gate and prepare the PR handoff

**Files:**
- Review: all Markdown files under `docs/`
- No repository PR-description file exists; provide the PR title/body in the final handoff.

**Interfaces:**
- Consumes: all documentation edits from Tasks 1–4 and the current source/configuration tree.
- Produces: verification evidence and a ready-to-paste PR description.

- [ ] **Step 1: Scan active docs for obsolete implementation claims.**

  Run:

  ```sh
  rg --no-index -n -i -e 'adapter\.in|adapter\.out|application\.port|application\.service|com\.incode\.verification\.configuration|StartVerificationService|ProviderResolutionService' docs/README.md docs/adr docs/architecture
  ```

  Expected: no output.

- [ ] **Step 2: Verify current package references against production source.**

  Run:

  ```sh
  for package in config controller service repository client mapper exception util; do test -d "company-check-service/src/main/java/com/incode/verification/$package"; done
  rg --no-index -n -e 'config|controller|service|repository|client|mapper|exception|PostgreSQL|Caffeine|Redis|FREE|PREMIUM' docs/architecture docs/adr
  ```

  Expected: all eight package directories exist and current architecture concepts are represented.

- [ ] **Step 3: Run formatting and topology checks.**

  ```sh
  git diff --check
  docker compose -f compose.yaml -f compose.single.yaml config
  docker compose -f compose.yaml -f compose.distributed.yaml config
  ```

  Expected: `git diff --check` exits 0 and both Compose merges render. If the Docker Compose plugin is unavailable, run the repository-supported standalone `docker-compose` equivalent and report the exact command/result.

- [ ] **Step 4: Confirm only intended files changed.**

  ```sh
  git status --short
  git diff --name-only
  git diff --cached --name-only
  git diff --submodule=short -- company-check-service
  ```

  Expected: documentation commits contain only intended Markdown files; the pre-existing dirty service submodule remains preserved and is not staged by the documentation commits.

- [ ] **Step 5: Prepare the PR handoff.**

  Provide a concise title such as `docs: align documentation with layered backend`, followed by a body with:

  ```markdown
  ## Summary
  - Updated ADRs, architecture diagrams, request/resilience/expiration workflows, and runtime/deployment guidance for the layered backend.
  - Labeled superseded architecture proposals as historical records.
  - Kept API, persistence, provider, Compose, and observability behavior unchanged.

  ## Validation
  - `git diff --check`
  - Markdown link check
  - Mermaid fence/reference scan
  - Single-node and distributed Compose config rendering

  ## Notes
  - Existing unrelated `company-check-service` submodule changes were preserved.
  - Report any unavailable Docker/Compose prerequisite with its exact command output.
  ```

- [ ] **Step 6: Final review before claiming completion.**

  Re-read the approved design spec, compare every acceptance criterion to the verification output, and report any failed or unavailable check instead of claiming success.
