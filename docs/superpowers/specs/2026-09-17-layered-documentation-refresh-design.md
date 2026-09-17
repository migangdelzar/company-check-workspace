# Layered Architecture Documentation Refresh

## Scope

Refresh every Markdown document under `docs/` that describes the Company Check
service, its architecture, runtime workflows, ADRs, validation, or development
topology. The documentation must match the checked-out implementation, whose
backend uses a conventional layered Spring Boot structure.

The provider simulator, public HTTP contracts, persistence schema, Compose
topologies, and runtime behavior are documentation inputs only; this change
does not modify them.

## Current source of truth

The backend layers are:

- `config` — Spring composition root, profiles, properties, infrastructure,
  resilience, persistence, and runtime hints.
- `controller` — HTTP controllers, request/response DTOs, inbound admission,
  and expiration scheduling.
- `service` — verification/provider workflows and `service/model` records.
- `repository` — JDBC persistence, coordination, leases, caches, and rate
  limiting.
- `client` — typed FREE/PREMIUM provider clients, wire DTOs, and provider
  transport handling.
- `mapper` — explicit conversions between controller, service, repository, and
  provider representations.
- `exception` — business/integration errors and HTTP error translation.
- `util` — narrowly scoped utility code such as UUID generation.

PostgreSQL remains authoritative. Caffeine is local cache state. Redis is used
for shared coordination, cache, leases, and rate limits only in distributed
mode. FREE is attempted before PREMIUM fallback. The provider remains a
separate Bun/Fastify deployable simulator.

## Documentation changes

### ADRs and indexes

- Update ADR 0001 and its index entry to describe layered Modulith boundaries.
- Replace stale package, class, and configuration claims in ADRs 0002–0008
  with the current repository/client/configuration terminology.
- Keep existing ADR filenames and links stable.
- Keep historical rationale explicit when an ADR explains a rejected
  hexagonal/over-factored alternative.

### Architecture pages and diagrams

- Make `overview.md` and `runtime-architecture.md` map every layer to actual
  packages and representative classes.
- Update request, resilience, expiration, and deployment diagrams to use the
  current `controller`, `service`, `repository`, `client`, `mapper`, and
  `exception` boundaries.
- Keep PostgreSQL-first semantics, local/distributed profile differences,
  provider fallback, bounded resources, Compose overlays, and observability
  behavior unchanged.
- Update testing, startup, and documentation indexes where commands, package
  names, or cross-links are stale.

### Historical Superpowers records

Do not rewrite prior design intent or implementation plans. Add concise
historical-status wording where a pre-layered proposal could otherwise be read
as the current architecture. The completed architecture-refresh plan may be
updated only to make its delivered status and verification outcome explicit.

## Boundaries and non-goals

- Modify Markdown files under `docs/` only.
- The repository has no PR-template or standalone PR-description file. Prepare
  the final PR title/body as a handoff artifact in the completion response,
  including changed documentation areas, validation results, and any
  environment limitations; do not modify remote PR metadata.
- Do not change Java, TypeScript, Compose, OpenAPI, Gradle, or workflow YAML
  files.
- Do not rename ADR files.
- Do not invent package names or behavior absent from the checked-out source.
- Do not change API paths, status codes, persistence semantics, or operational
  commands unless the source/configuration proves the current documentation is
  wrong.

## Verification

Run these checks after editing:

1. Search `docs/` for obsolete implementation references such as `adapter.*`,
   `application.port`, `application.service`, `configuration.*`,
   `StartVerificationService`, and `ProviderResolutionService`; remaining
   matches must be clearly labeled historical context.
2. Check Markdown links resolve to files that exist in the workspace.
3. Check every Mermaid fence is balanced and diagrams contain current class or
   package names.
4. Run `git diff --check`.
5. Render both single-node and distributed Compose configurations when the
   local Compose implementation is available; report environment limitations
   without changing runtime configuration.

## Acceptance criteria

- Current ADRs, architecture pages, diagrams, workflows, indexes, and testing
  guidance consistently describe the layered backend.
- No active documentation claims that production classes live under the old
  `adapter`, `application`, or `domain` package tree.
- Historical records remain understandable and are clearly distinguished from
  current architecture guidance.
- All verification checks complete, with failures or unavailable external
  prerequisites reported precisely.
