# Architectural & Structural Modernization Design

| Field | Detail |
|---|---|
| Date | 2026-09-16 |
| Status | Proposed |
| Scope | `company-check-workspace`, with primary implementation in `company-check-service` |
| Related documentation | [`docs/adr/`](../../adr/), [`docs/architecture/`](../../architecture/) |

## 1. Goal

Audit and harden the existing Company Check modernization work without
changing public API behavior, provider fixtures/contracts, persistence schema,
or the intended single-node and distributed runtime profiles.

The work is verification-driven. Existing user changes remain authoritative;
only confirmed gaps, regressions, inconsistent configuration, and missing
coverage are changed.

## 2. Constraints and invariants

- Keep `GET /backend-service` and `GET /verifications/{verificationId}`
  behavior aligned with the OpenAPI contract and controller implementation.
- Keep the domain free of Spring, HTTP, JDBC, Redis, caching, and other
  infrastructure dependencies.
- Keep application services dependent on application ports and domain types;
  keep concrete adapter and infrastructure dependencies at configuration or
  adapter boundaries.
- PostgreSQL is authoritative for verification identity, status, expiry, and
  terminal results. Redis and Caffeine may coordinate, lease, rate-limit, or
  cache, but cannot become the source of verification truth.
- Preserve provider route shapes, deterministic fixtures, scenario ordering,
  health routes, and the Bun/Fastify provider boundary.
- Keep scarce resources explicitly bounded: database connections, Redis pool
  resources, provider HTTP connections, provider concurrency, and rate limits.
- Use tests before behavior changes. Do not remove or weaken existing tests or
  JaCoCo/quality gates.
- Preserve unrelated worktree changes and do not reset, discard, or silently
  overwrite pending edits.

## 3. Target architecture

```text
configuration
  -> application services and ports
  -> inbound adapters
  -> outbound adapters

adapter.in  -> application.port.in
adapter.out -> application.port.out
application -> application ports + domain
domain      -> Java standard library only
```

The top-level `com.incode.verification.configuration` package is the Spring
composition root. It owns bean wiring, profile selection, properties, resource
limits, and infrastructure policy composition. Configuration and property
binding types are grouped by context under `application`, `persistence`,
`coordination`, `provider`, `web`, and `observability`. Configuration may
import adapter implementations, and adapters may receive immutable property
records from that composition root. Application and domain code must not
import configuration or adapter implementations.

The adapter layout is:

- `adapter.in.web`: HTTP request/response translation and exception mapping.
- `adapter.in.scheduling`: scheduled expiration trigger.
- `adapter.out.persistence`: JDBC/JdbcClient access to PostgreSQL.
- `adapter.out.coordination`: local or Redis coordination and leases.
- `adapter.out.provider`: provider HTTP adapters and provider policy wrappers.
- `adapter.out.ratelimit`: local or Redis rate-limit implementations.

Domain types are grouped by business concept under `company`, `identity`,
`provider`, `query`, and `verification`.

## 4. Runtime and data flow

### Request flow

1. The inbound filter performs bounded admission control.
2. The web adapter maps the request into an application command.
3. The application service reads PostgreSQL first for an existing verification
   ID and enforces idempotency/conflict behavior.
4. For a new query, coordination prevents duplicate provider work across local
   threads or distributed replicas.
5. The owning application flow reuses an authoritative completed PostgreSQL
   result when valid; otherwise it calls the selected provider through the
   bounded HTTP/resilience boundary.
6. The terminal result is committed to PostgreSQL before optional cache or
   coordination publication.
7. Retrieval reads PostgreSQL and does not call providers.

### Expiration flow

Every replica may trigger expiration. A local lock limits ownership in the
single-node profile; a Redis token lease limits ownership in the distributed
profile. The owner repeatedly claims bounded batches using PostgreSQL row
locking with `SKIP LOCKED`, updates expired `IN_PROGRESS` records, and releases
the lease with token ownership checks. Loss of Redis does not change the
authoritative state model.

### Provider resilience flow

Provider requests use a shared, bounded Apache HttpClient 5 execution pool with
explicit connection-request, connect, response, and overall attempt
deadlines. Resilience4j policies are applied per provider boundary in a stable
order: retry transient failures, circuit-break unhealthy providers, reject
rate-limit excess work, and bound concurrent calls with a bulkhead. Contract
failures are not retried.

## 5. Work packages

The implementation plan will inspect each package and configuration item, then
make only the smallest change needed:

1. **Boundary audit** — strengthen ArchUnit/Spring Modulith tests for package
   dependency directions, framework-free domain code, and composition-root
   wiring.
2. **Configuration audit** — verify property binding, profile selection, bean
   conditions, and explicit bounds for JDBC, Redis, HTTP, virtual threads, and
   Resilience4j. Fix inconsistencies found by tests or build validation.
3. **Persistence and coordination audit** — verify PostgreSQL-first reads and
   writes, transaction/retry behavior, lease ownership, cache invalidation, and
   degraded Redis behavior using unit and integration tests.
4. **Provider boundary audit** — verify pooled HTTP construction, timeouts,
   provider mapping, retry classification, circuit/rate/bulkhead behavior, and
   resource shutdown.
5. **Contract/build/deployment audit** — validate OpenAPI/controller parity,
   Gradle convention ownership, immutable image inputs, Compose overlays, and
   documentation commands.
6. **Documentation completion** — keep ADRs in `docs/adr/`; keep current
   topology and Mermaid request/expiration/testing diagrams in
   `docs/architecture/`; update links and commands only when implementation
   behavior changes.

## 6. Error handling

| Boundary | Expected behavior |
|---|---|
| Invalid query or request | Preserve existing boundary validation and error response. |
| Verification ID conflict | Return the existing conflict behavior; never invoke a provider. |
| Missing verification | Preserve the existing not-found response. |
| Provider contract failure | Map to the existing application failure; do not retry. |
| Provider transient failure | Apply bounded retry and existing fallback/error semantics. |
| Provider rate/circuit/bulkhead rejection | Fail fast through the existing provider/application mapping. |
| PostgreSQL failure | Apply configured bounded retry where supported; do not promote cache to authority. |
| Redis failure | Follow the selected adapter’s explicit degraded behavior; never report unverified cache state as authoritative. |
| Expiration lease loss | Stop or skip the batch safely; PostgreSQL ownership/state rules remain authoritative. |
| Resource exhaustion | Reject or time out within configured bounds; never create unbounded pools or queues. |

## 7. Test strategy

Follow red → green → refactor for each confirmed gap.

- **Architecture tests:** package dependency directions, domain isolation,
  configuration ownership, and forbidden legacy packages.
- **Application unit tests:** fakes for repository, coordination, expiration
  lock, and provider ports; cover idempotency, conflict, recovery, expiration,
  fallback, and PostgreSQL-first semantics.
- **Adapter unit tests:** JDBC SQL/data mapping, Redis scripts/lease behavior,
  local coordination, provider mapping, and resilience classification.
- **Spring slice/configuration tests:** bean presence by profile, property
  binding, pool/resource bounds, HTTP client construction, and OpenAPI route
  parity.
- **Integration tests:** Testcontainers PostgreSQL and Redis for transaction,
  concurrency, recovery, and distributed rate/lease behavior.
- **Workspace checks:** provider `bun run quality`, Compose config rendering,
  service `fastCheck`, and service `qualityGate` when Docker is available.

No test should rely on a real external provider in unit scope. Network and
database behavior belongs in realistic integration tests.

## 8. Definition of done

- All target package and dependency-direction checks pass.
- Existing API, persistence, provider, and fixture contracts remain unchanged.
- Resource limits and profile behavior are explicit and tested.
- PostgreSQL authority and Redis coordination semantics are tested.
- Provider resilience and HTTP pool behavior are tested at the appropriate
  boundary.
- OpenAPI, Compose, README, ADR, and architecture indexes are internally
  consistent.
- `fastCheck` passes; `qualityGate` and provider quality are run when their
  external prerequisites are available and any environment blocker is
  reported precisely.
- No unrelated user changes are staged, discarded, or overwritten.
