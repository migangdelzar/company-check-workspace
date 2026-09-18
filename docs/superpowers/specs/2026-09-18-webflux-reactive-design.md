# WebFlux Reactive Service Design

Date: 2026-09-18  
Status: Approved design; implementation not started  
Feature branch: `feat/webflux-reactive`

## Goal

Create an end-to-end reactive variant of `company-check-service` for a fair
comparison with the current virtual-thread MVC implementation. The reactive
variant must preserve the existing public API, domain behavior, persistence
schema, provider behavior, resilience rules, observability, local stack, and
native-image workflow.

The request path will use WebFlux, WebClient, R2DBC, and reactive Redis. The
existing `main` branch will remain unchanged until a later benchmark review
explicitly chooses whether to merge any part of this work.

## Branch and repository boundaries

The workspace is a Git superproject with `company-check-service` as a
submodule. The implementation will use matching feature branches:

```text
company-check-workspace       feat/webflux-reactive
company-check-service         feat/webflux-reactive
```

The service branch will contain the application implementation and tests. The
workspace branch will contain the updated submodule pointer and any workspace
workflow or documentation changes required to run the comparison. The
provider submodule is not in scope.

Gradle will continue to run from `company-check-service`; no root Gradle build
will be introduced.

## Scope

### In scope

- Replace Spring MVC request handling with Spring WebFlux.
- Replace blocking provider calls with WebClient and Reactor Netty.
- Replace request-path JDBC persistence with R2DBC PostgreSQL.
- Replace synchronous Redis coordination and distributed rate limiting with
  reactive Redis operations.
- Convert services, repository ports, coordination ports, provider ports,
  filters, scheduled expiration, and exception handling to reactive flows.
- Preserve the current single-node and distributed profiles.
- Preserve provider fallback, retry, circuit breaker, bulkhead, rate-limit,
  claim, completion, cache, lease, recovery, and expiration semantics.
- Preserve API contracts, database schema, metrics, logs, traces, dashboards,
  Docker images, mise commands, and native-image support.
- Add reactive unit, integration, contract, architecture, and performance
  verification.

### Out of scope

- Changing endpoint paths, request parameters, response JSON, or HTTP status
  semantics.
- Changing PostgreSQL schema or migration meaning.
- Changing provider selection or business rules.
- Converting the provider submodule.
- Merging the feature branch into `main` without a separate benchmark review.
- Keeping MVC and WebFlux runtime modes in the same application artifact.

## Runtime architecture

The request path will be:

```text
HTTP request
  -> WebFlux controller
  -> reactive verification service
  -> R2DBC PostgreSQL repository
  -> reactive coordination/cache
  -> WebClient provider call
  -> reactive persistence transaction
  -> cache publication after commit
  -> HTTP response
```

Controllers will return `Mono<ResponseEntity<...>>`. Service and adapter
boundaries will return `Mono<T>` for one result and `Flux<T>` only where a
stream is meaningful. Domain records remain synchronous immutable values; pure
normalization, mapping, and state transitions remain ordinary Java code.

The response contract remains identical to the current MVC implementation.
The controller must never call `.block()`.

## Framework and dependency changes

The service build will make these substitutions:

```text
spring-boot-starter-web       -> spring-boot-starter-webflux
RestClient + Apache HttpClient -> WebClient + Reactor Netty
JdbcClient + Hikari           -> R2DBC DatabaseClient + PostgreSQL R2DBC
StringRedisTemplate            -> ReactiveStringRedisTemplate
RetryTemplate                  -> Reactor retryWhen/retryWhenAsync
TransactionTemplate            -> R2dbcTransactionManager + TransactionalOperator
```

Flyway migrations will remain enabled. If the Spring Boot/Flyway integration
requires JDBC during startup, the JDBC driver and startup-only JDBC support may
remain isolated for migration execution. No request handler, provider client,
coordination adapter, rate limiter, or repository will use JDBC.

The blocking Apache HTTP client will be removed from the provider request path.
The WebClient connection pool and timeout configuration will be mapped from the
existing provider properties so current connection, connect, response, and
idle-eviction limits remain meaningful.

Virtual-thread configuration will be disabled for the reactive profile/branch
to keep performance measurements attributable to WebFlux rather than a mixed
execution model. Netty event-loop resources will be managed by the WebFlux
runtime.

## Component design

### Controllers and inbound filtering

Controllers will retain their current routes, validation annotations, cache
headers, and response mappers while returning reactive types. The inbound rate
limiter will become a WebFlux `WebFilter`. Local decisions will remain
immediate; distributed decisions will use reactive Redis.

The existing exception mappings will be adapted to WebFlux-compatible advice
without changing their status codes or error bodies.

### Verification service

`VerificationService.start` and `get` will compose repository, coordination,
provider, and store operations with `flatMap`, `switchIfEmpty`, and equivalent
Reactor operators. Pure domain decisions will remain synchronous inside
`map`/`handle` stages.

The existing idempotency and conflict behavior remains:

1. Normalize the request.
2. Read by verification ID.
3. Return the existing terminal result or reject conflicting reuse.
4. Insert an in-progress row when absent.
5. Resolve through coordination and providers.
6. Claim and complete the row atomically.

### Provider clients and resilience

The provider port will become `Mono<ProviderResult> lookup(NormalizedQuery)`.
WebClient will decode provider payloads reactively and map HTTP/status/timeout
failures to the existing provider failure model.

Free-to-premium fallback remains sequential and conditional on the free result.
Resilience4j will be applied through Reactor operators/decorators rather than
assuming synchronous annotation interception. Existing instance names, retry
conditions, circuit-breaker thresholds, rate limits, bulkhead limits, and
fallback behavior will be retained.

The distributed provider limiter will execute the existing Lua decision as a
reactive Redis script. Redis failure will continue to reject provider access.

### Persistence and transactions

`JdbcVerificationRepository` will be replaced by an R2DBC implementation using
Spring's reactive `DatabaseClient` and the existing SQL semantics. It will
preserve UUID, timestamp, JSONB, status, claim-token, row-lock, and
`SKIP LOCKED` behavior.

Repository methods will become reactive, including insert, lookup, claim,
completion, shared-result lookup, and expiration batch updates.

`R2dbcTransactionManager` and `TransactionalOperator` will replace
`TransactionTemplate`. The claim/complete sequence will remain atomic. Reactive
database retry will only retry the configured transient data-access failures.

Cache publication will be chained after the transactional publisher completes,
which ensures it happens after commit. A failed cache publication will preserve
the existing cache failure semantics and will not undo a committed database
result.

### Coordination and leases

The coordination port will become reactive. The distributed implementation will
use reactive Redis values, Lua scripts, and lease release operations. The local
implementation will keep its non-waiting per-query ownership semantics and
reactive return types without introducing a blocking lock wait.

Lease lifetime will be managed with an asynchronous resource pattern equivalent
to Reactor `usingWhen`, ensuring release on success, error, and cancellation.
An unacquired lease will use the existing cached/shared/in-progress path; a
degraded lease will fail closed as it does today.

### Expiration and recovery

Recovery and expiration will use reactive repository operations. The scheduler
will execute one reactive drain at a time, preserve the distributed expiration
lock, process the existing batch size, and continue draining while a full batch
is returned. Startup recovery and periodic reaping will share the same
nonblocking drain operation and will not overlap.

## Observability

Actuator, Micrometer, OpenTelemetry, Prometheus, Loki, Tempo, Grafana, and the
existing dashboard will remain enabled. Existing observation names such as
`verification.start`, `verification.get`, and provider resolution will be
preserved.

Reactive context propagation must preserve trace/span correlation across
WebClient, R2DBC, Redis, retry, and scheduler boundaries. Verification will
include:

- actuator health and Prometheus endpoints;
- request, provider, database, Redis, and error metrics;
- structured logs with correlation metadata;
- traces reaching Tempo through the existing OTLP pipeline; and
- dashboard panels showing request rate, errors, latency, resources, logs, and
  traces.

## Testing strategy

- Unit tests use `StepVerifier` for reactive services, provider mapping,
  fallback, retry, cancellation, lease cleanup, and error mapping.
- WebFlux tests verify routes, validation, headers, payloads, and status codes.
- PostgreSQL Testcontainers verify Flyway startup, R2DBC SQL mapping, JSONB,
  transactions, claim/completion races, shared lookups, and expiration.
- Redis Testcontainers verify reactive scripts, coordination leases, cache
  behavior, distributed rate limits, and fail-closed behavior.
- Contract tests continue to validate the unchanged external API.
- Architecture tests reject MVC controllers, `RestClient`, synchronous Redis
  templates, request-path JDBC, `.block()`, and other blocking adapters.
- JVM container startup is verified through the existing mise/Compose workflow.
- Native-image compilation and startup are verified after the JVM path passes.

## Benchmark and acceptance criteria

The reactive image will be exercised with the existing observability stack and
at least 10,000 Locust requests. The comparison against the current JVM image
will use the same request mix, provider behavior, duration, and concurrency.

The benchmark will record:

- completed requests and failures;
- throughput and p95/p99 latency;
- process RSS and CPU;
- R2DBC pool utilization;
- Redis and provider concurrency;
- event-loop saturation or queued work; and
- persisted verification count, metrics, logs, and traces.

Acceptance requires behavioral parity, passing verification suites, successful
JVM and native startup, no blocking request-path dependencies, persisted data,
and observable metrics/logs/traces. Performance results will be documented for
comparison; they will not automatically determine a merge decision.

## Delivery sequence

1. Commit this design specification on the workspace feature branch.
2. After specification review, create the matching service feature branch.
3. Implement dependencies and reactive ports/adapters in small tested commits.
4. Verify unit, integration, contract, architecture, JVM, native, and
   observability workflows.
5. Run the bounded Locust comparison and document the results.
6. Commit the service implementation and update the workspace submodule pointer.
7. Leave both feature branches available for review; merge only after explicit
   approval based on the benchmark and code review.
