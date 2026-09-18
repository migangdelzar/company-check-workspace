# WebFlux Reactive Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an end-to-end reactive `company-check-service` on `feat/webflux-reactive`, preserving the current API and business behavior while replacing request-path MVC, blocking HTTP, JDBC, and synchronous Redis with WebFlux, WebClient, R2DBC, and reactive Redis.

**Architecture:** Convert the existing service in place on a matching service feature branch. Keep the domain records and SQL/schema semantics, change adapter ports to Reactor types, and implement reactive providers, persistence, coordination, rate limiting, filters, and scheduling. Keep Flyway JDBC only for startup migrations if required by Spring Boot.

**Tech Stack:** Spring Boot 4.1.1, Java 25, Spring WebFlux, Reactor Netty, Spring Data R2DBC, PostgreSQL R2DBC, Spring Data Redis reactive Lettuce, Resilience4j Reactor operators, Micrometer/OpenTelemetry, Testcontainers, Gradle Kotlin DSL, Docker Compose, mise, Locust.

## Required execution order

Follow the numbered tasks in this order even though the file map is grouped by
responsibility: Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8,
Task 9, then Task 10. Each task ends with its own test gate and commit.

## Global Constraints

- Run Gradle only from `company-check-service`; do not add a root Gradle build.
- Preserve the public API, database schema, provider behavior, resilience limits, observability names, Compose stack, mise workflows, and native-image workflow.
- The request path must not use JDBC, `RestClient`, synchronous Redis templates, blocking filesystem calls, or `.block()`.
- Keep `single-node` and `distributed` profiles and preserve fail-closed Redis behavior.
- Keep `company-check-provider` unchanged.
- Use Java 25 and Spring Boot 4.1.1 from the existing catalog.
- Use TDD: write the focused failing test, run it, implement the minimum change, run the focused test, then run the relevant broader gate.
- Commit service changes on `feat/webflux-reactive`; update the workspace submodule pointer only after the service commit is available.
- Do not merge either feature branch into `main` as part of implementation.

---

### Task 6: Convert verification services and lease lifecycle

**Files:**
- Modify `src/main/java/com/incode/verification/service/VerificationService.java`.
- Modify `src/main/java/com/incode/verification/service/VerificationStoreService.java`.
- Modify `src/main/java/com/incode/verification/service/VerificationRecoveryService.java`.
- Modify `src/main/java/com/incode/verification/service/ProviderService.java` if composition remains there after Task 4.
- Modify `src/test/java/com/incode/verification/service/VerificationServiceTest.java`.
- Modify `src/test/java/com/incode/verification/service/ProviderServiceTest.java`.
- Modify `src/integrationTest/java/com/incode/verification/application/VerificationRecoveryIT.java`.

**Interfaces:**
- `VerificationService.start(...)` and `get(...)` return `Mono<VerificationResult>`.
- `VerificationStoreService.store(...)` returns `Mono<VerificationResult>`.
- `VerificationRecoveryService.recover`, `cached`, and `shared` return `Mono<VerificationResult>`.

- [ ] **Step 1: Add failing service tests for reactive idempotency and fallback**

Convert the existing scenarios to `StepVerifier` and add assertions for:

```java
StepVerifier.create(service.start(command))
    .assertNext(result -> assertEquals(VerificationStatus.COMPLETED, result.status()))
    .verifyComplete();
StepVerifier.create(service.start(conflictingCommand))
    .expectError(VerificationConflictException.class)
    .verify();
```

Assert that insertion occurs before provider lookup, shared results avoid
provider calls, degraded coordination fails closed, terminal failures map to
`ProviderSubmissionException`, and cancellation releases the coordination lease.

- [ ] **Step 2: Implement reactive `VerificationService` composition**

Use `flatMap`, `switchIfEmpty`, `defer`, and `usingWhen`. The lease body must
follow this shape:

```java
coordination.acquire(query)
    .flatMap(lease -> Mono.usingWhen(
        Mono.just(lease),
        current -> resolveWithLease(verification, query, current),
        CoordinationRepository.Lease::release));
```

Never perform provider, R2DBC, or Redis work before subscription; use `defer`
where UUID generation or current time must be evaluated per subscription.

- [ ] **Step 3: Implement reactive store/recovery composition**

Ensure `TransactionalOperator` encloses claim and completion, the reload path
uses `Mono.switchIfEmpty`, and cache publication is chained only after the
transactional publisher completes. Convert after-commit synchronization to
publisher ordering rather than servlet transaction callbacks.

- [ ] **Step 4: Run service and recovery tests**

```bash
./gradlew test --tests com.incode.verification.service.VerificationServiceTest --tests com.incode.verification.service.ProviderServiceTest --tests com.incode.verification.service.ExpirationServiceTest
./gradlew integrationTest --tests com.incode.verification.application.VerificationRecoveryIT --no-parallel --max-workers=1
```

- [ ] **Step 5: Commit reactive service orchestration**

```bash
git add src/main/java/com/incode/verification/service src/test/java/com/incode/verification/service src/integrationTest/java/com/incode/verification/application
git commit -m "feat: compose verification workflow reactively"
```

---

### Task 7: Convert WebFlux controllers, filter, errors, and expiration scheduler

**Files:**
- Modify `src/main/java/com/incode/verification/controller/VerificationController.java`.
- Modify `src/main/java/com/incode/verification/controller/BackendServiceController.java`.
- Replace `src/main/java/com/incode/verification/filter/InboundRateLimitFilter.java` with a WebFlux `WebFilter`.
- Modify `src/main/java/com/incode/verification/exception/handler/GlobalExceptionHandler.java`.
- Modify `src/main/java/com/incode/verification/scheduler/VerificationExpirationScheduler.java`.
- Modify `src/test/java/com/incode/verification/controller/VerificationControllerTest.java`.
- Modify `src/test/java/com/incode/verification/controller/BackendServiceControllerTest.java`.
- Modify `src/test/java/com/incode/verification/controller/VerificationControllerSliceTest.java`.
- Modify `src/test/java/com/incode/verification/filter/InboundRateLimitFilterTest.java`.
- Modify `src/test/java/com/incode/verification/exception/handler/GlobalExceptionHandlerTest.java`.
- Modify `src/test/java/com/incode/verification/scheduler/VerificationExpirationSchedulerTest.java`.

**Interfaces:**
- Controllers return `Mono<ResponseEntity<VerificationResponse>>`.
- Filter implements `org.springframework.web.server.WebFilter`.
- Scheduler exposes a reactive drain publisher and subscribes only through managed application lifecycle hooks.

- [ ] **Step 1: Write failing WebFlux route and filter tests**

Use `WebTestClient` to verify:

```java
webTestClient.get()
    .uri(uriBuilder -> uriBuilder.path("/backend-service")
        .queryParam("verificationId", id)
        .queryParam("query", "Acme")
        .build())
    .exchange()
    .expectStatus().isOk()
    .expectHeader().valueEquals("Cache-Control", "no-store");
```

Cover validation, 404, conflict, provider failure, inbound `429`, unavailable
`503`, `Retry-After`, and unchanged JSON `ProblemDetail` output.

- [ ] **Step 2: Convert controllers and advice**

Keep `VerificationMapper.map` and response DTOs unchanged. Return the mapped
response from `Mono.map` and preserve `ResponseEntity` headers. Keep the
existing exception classes and status/code mapping.

- [ ] **Step 3: Implement the WebFlux `WebFilter`**

Filter only `GET /backend-service`, call the reactive limiter, write the same
status and headers for rejection/unavailability, and return `chain.filter(exchange)`
for allowed requests. Do not use servlet request/response types.

- [ ] **Step 4: Implement non-overlapping reactive expiration**

Create one drain publisher that acquires the expiration lease, expires one
batch, releases the lease, and repeats only while the batch is full. Use a
single serialized subscription for startup recovery and periodic scheduling.
No `block`, `sleep`, or synchronous repository call is permitted.

- [ ] **Step 5: Run WebFlux and scheduler tests**

```bash
./gradlew test --tests com.incode.verification.controller.VerificationControllerTest --tests com.incode.verification.controller.BackendServiceControllerTest --tests com.incode.verification.controller.VerificationControllerSliceTest --tests com.incode.verification.filter.InboundRateLimitFilterTest --tests com.incode.verification.exception.handler.GlobalExceptionHandlerTest --tests com.incode.verification.scheduler.VerificationExpirationSchedulerTest
```

- [ ] **Step 6: Commit the WebFlux HTTP boundary**

```bash
git add src/main/java/com/incode/verification/controller src/main/java/com/incode/verification/filter src/main/java/com/incode/verification/exception/handler src/main/java/com/incode/verification/scheduler src/test/java/com/incode/verification/controller src/test/java/com/incode/verification/filter src/test/java/com/incode/verification/exception/handler src/test/java/com/incode/verification/scheduler
git commit -m "feat: expose reactive WebFlux endpoints"
```

---

### Task 8: Update configuration, observability, native hints, and architecture rules

**Files:**
- Modify `src/main/java/com/incode/verification/config/ObservabilityConfiguration.java` only if reactive observation/context propagation requires it.
- Modify `src/main/java/com/incode/verification/config/hints/ProviderRuntimeHints.java` and related hints if R2DBC/WebClient/Redis native analysis requires registrations.
- Modify `src/test/java/com/incode/verification/config/ObservabilityConfigurationTest.java`.
- Modify `src/test/java/com/incode/verification/config/RuntimeProfileConfigurationTest.java`.
- Modify `src/test/java/com/incode/verification/architecture/LayeredDependencyTest.java`, `LayerPackageStructureTest.java`, and `ServiceModelArchitectureTest.java`.
- Create `src/test/java/com/incode/verification/architecture/ReactiveBoundaryArchitectureTest.java`.
- Modify `src/test/java/com/incode/verification/config/IncodeCompositionTest.java`.

**Interfaces:**
- The reactive application context must expose WebFlux, R2DBC, reactive Redis, provider WebClient, transaction, and observability beans for the active profile.

- [ ] **Step 1: Add failing architecture assertions**

Add rules that production request-path classes do not depend on:

```java
org.springframework.web.client.RestClient.class
org.springframework.jdbc.core.simple.JdbcClient.class
org.springframework.data.redis.core.StringRedisTemplate.class
jakarta.servlet.Filter.class
```

Also scan production bytecode/source for `.block(`, `.get(` on futures, and
the blocking Apache HTTP client package. Permit JDBC only in explicitly
startup-only Flyway configuration if it remains necessary.

- [ ] **Step 2: Verify observations across reactive boundaries**

Keep `@Observed` names and add tests that a WebTestClient request produces the
same observation names. Verify WebClient, R2DBC, Redis, retry, and scheduler
signals retain tracing context in the existing OTLP configuration.

- [ ] **Step 3: Verify native reachability and runtime hints**

Run the existing runtime-hint tests, add R2DBC/WebClient/Redis reachability
metadata only when the native analysis identifies a concrete missing type, and
keep the existing provider DTO hints intact.

- [ ] **Step 4: Run fast quality and architecture gates**

```bash
./gradlew fastCheck
./gradlew test --tests com.incode.verification.architecture.ReactiveBoundaryArchitectureTest --tests com.incode.verification.config.ObservabilityConfigurationTest --tests com.incode.verification.config.RuntimeProfileConfigurationTest --tests com.incode.verification.config.IncodeCompositionTest
```

Expected: no blocking request-path dependency is present and the reactive
application context starts for both profiles.

- [ ] **Step 5: Commit the reactive architecture guardrails**

```bash
git add src/main/java/com/incode/verification/config src/main/java/com/incode/verification/config/hints src/test/java/com/incode/verification/architecture src/test/java/com/incode/verification/config
git commit -m "test: enforce reactive request boundaries"
```

---

### Task 2: Convert reactive ports and test doubles

**Files:**
- Modify `src/main/java/com/incode/verification/client/ProviderClient.java`.
- Modify `src/main/java/com/incode/verification/repository/VerificationRepository.java`.
- Modify `src/main/java/com/incode/verification/repository/CoordinationRepository.java`.
- Modify `src/main/java/com/incode/verification/repository/ExpirationLock.java`.
- Modify `src/main/java/com/incode/verification/repository/InboundRateLimiter.java`.
- Modify `src/main/java/com/incode/verification/repository/ratelimit/ProviderRateLimiter.java`.
- Modify affected service test doubles in `VerificationServiceTest.java`, `ProviderServiceTest.java`, `ExpirationServiceTest.java`, and coordination tests.

**Interfaces:**

```java
public interface ProviderClient {
  Mono<ProviderResult> lookup(NormalizedQuery query);
}

public interface VerificationRepository {
  Mono<Boolean> insertInProgress(Verification verification);
  Mono<Verification> findById(UUID id);
  Mono<Verification> findByQuery(NormalizedQuery query);
  Mono<UUID> claim(UUID id);
  Mono<Boolean> complete(UUID id, UUID claimToken, Verification verification);
  Mono<Integer> expireBatch(Instant now, int limit);
}

public interface CoordinationRepository {
  Mono<Lease> acquire(NormalizedQuery query);
  Mono<VerificationResult> get(NormalizedQuery query);
  Mono<VerificationResult> put(NormalizedQuery query, VerificationResult result);

  interface Lease {
    boolean acquired();
    boolean degraded();
    Mono<Void> release();
  }
}

public interface InboundRateLimiter {
  Mono<Decision> tryAcquire();
}

public interface ProviderRateLimiter {
  Mono<Boolean> tryAcquire(ProviderType provider);
}
```

`Mono.empty()` replaces nullable/optional absence for lookups and failed
claims. `Lease.release()` is idempotent and completes after asynchronous Redis
release has finished.

- [ ] **Step 1: Write failing `StepVerifier` tests for the new port behavior**

```java
StepVerifier.create(repository.findById(missingId)).verifyComplete();
StepVerifier.create(repository.claim(missingId)).verifyComplete();
StepVerifier.create(provider.lookup(query))
    .expectNext(expectedResult)
    .verifyComplete();
StepVerifier.create(lease.release()).verifyComplete();
```

Expected: the existing synchronous test doubles no longer compile, proving the
port conversion is required.

- [ ] **Step 2: Change the production port signatures**

Replace `Optional`, nullable UUID returns, `AutoCloseable.close()`, and
synchronous result types with the exact interfaces above. Do not modify domain
records or SQL yet.

- [ ] **Step 3: Convert test doubles to deterministic publishers**

Use `Mono.just`, `Mono.empty`, `Mono.error`, and `Flux` only where needed.
Keep provider call recording in `AtomicInteger`/lists and assert results with
`StepVerifier` rather than `assertThrows` on publisher creation.

- [ ] **Step 4: Run the affected compile/test slice**

```bash
./gradlew test --tests com.incode.verification.service.VerificationServiceTest --tests com.incode.verification.service.ProviderServiceTest --tests com.incode.verification.service.ExpirationServiceTest --tests com.incode.verification.repository.coordination.LocalCoordinationRepositoryTest
```

Expected: this slice fails only because the production services/adapters still
use the old synchronous ports; no test double should remain synchronous.

- [ ] **Step 5: Commit the port contract**

```bash
git add src/main/java/com/incode/verification/client/ProviderClient.java src/main/java/com/incode/verification/repository src/test/java/com/incode/verification/service src/test/java/com/incode/verification/repository
git commit -m "refactor: define reactive service ports"
```

---

### Task 3: Convert persistence and transaction composition to R2DBC

**Files:**
- Create `src/main/java/com/incode/verification/repository/R2dbcVerificationRepository.java`.
- Delete `src/main/java/com/incode/verification/repository/JdbcVerificationRepository.java` after its tests are replaced.
- Modify `src/main/java/com/incode/verification/config/persistence/PersistenceConfiguration.java`.
- Modify `src/main/java/com/incode/verification/service/VerificationStoreService.java`.
- Modify `src/main/java/com/incode/verification/service/VerificationRecoveryService.java`.
- Modify `src/main/java/com/incode/verification/service/ExpirationService.java`.
- Create/modify `src/integrationTest/java/com/incode/verification/adapter/out/persistence/R2dbcVerificationRepositoryIntegrationTest.java`.
- Create/modify `src/integrationTest/java/com/incode/verification/adapter/out/persistence/R2dbcDataSliceTest.java`.

**Interfaces:**
- `R2dbcVerificationRepository implements VerificationRepository`.
- `DatabaseClient` is the only request-path SQL client.
- `TransactionalOperator` wraps claim/complete and reload behavior.

- [ ] **Step 1: Write failing R2DBC integration tests for insert, lookup, claim, complete, and expiry**

Use PostgreSQL Testcontainers and `StepVerifier` assertions such as:

```java
StepVerifier.create(repository.insertInProgress(inProgress))
    .expectNext(true)
    .verifyComplete();
StepVerifier.create(repository.findById(id))
    .assertNext(found -> assertEquals(id, found.id()))
    .verifyComplete();
StepVerifier.create(repository.claim(id)).assertNext(token -> assertNotNull(token)).verifyComplete();
StepVerifier.create(repository.complete(id, token, completed)).expectNext(true).verifyComplete();
StepVerifier.create(repository.expireBatch(now, 100)).expectNext(1).verifyComplete();
```

Cover duplicate insert, missing lookup, claim conflict, wrong claim token,
JSONB state mapping, normalized-query reuse, and `FOR UPDATE SKIP LOCKED` expiry.

- [ ] **Step 2: Implement R2DBC SQL mapping with existing statements**

Use `DatabaseClient.sql(...).bind(...)` and
`map((row, metadata) -> ...)`. Decode `state` through the existing
`VerificationStateMapper`, map PostgreSQL UUID and timestamps directly, and
return `Mono.empty()` for no row. Preserve the existing status predicates and
update counts exactly.

- [ ] **Step 3: Add R2DBC transaction beans**

Configure:

```java
@Bean
DatabaseClient databaseClient(ConnectionFactory connectionFactory) {
  return DatabaseClient.create(connectionFactory);
}

@Bean
R2dbcTransactionManager transactionManager(ConnectionFactory connectionFactory) {
  return new R2dbcTransactionManager(connectionFactory);
}

@Bean
TransactionalOperator verificationTransactionalOperator(
    R2dbcTransactionManager transactionManager) {
  return TransactionalOperator.create(transactionManager);
}
```

Keep Flyway migration configuration separate from the R2DBC transaction
manager. Do not expose a JDBC repository bean.

- [ ] **Step 4: Convert store/recovery/expiration transaction flows**

The store shape must be equivalent to:

```java
return claimAndComplete(verification)
    .as(transactionOperator::transactional)
    .retryWhen(databaseRetry)
    .flatMap(result -> result.status().isTerminal()
        ? coordination.put(query, result).thenReturn(result)
        : Mono.just(result));
```

Use Reactor retry filtering for transient database exceptions. Ensure cache
publication is downstream of `TransactionalOperator` so it happens after the
commit signal. Convert recovery and expiration lookups to `Mono` composition.

- [ ] **Step 5: Run persistence and service tests**

```bash
./gradlew test --tests com.incode.verification.service.VerificationServiceTest --tests com.incode.verification.service.ExpirationServiceTest
./gradlew integrationTest --tests com.incode.verification.adapter.out.persistence.R2dbcVerificationRepositoryIntegrationTest --tests com.incode.verification.adapter.out.persistence.R2dbcDataSliceTest --no-parallel --max-workers=1
```

Expected: unit tests pass and the PostgreSQL container proves rows are
inserted, claimed, completed, read, and expired through R2DBC.

- [ ] **Step 6: Commit the R2DBC persistence boundary**

```bash
git add src/main/java/com/incode/verification/repository src/main/java/com/incode/verification/config/persistence src/main/java/com/incode/verification/service src/integrationTest/java/com/incode/verification/adapter/out/persistence
git commit -m "feat: migrate persistence to R2DBC"
```

---

### Task 4: Convert provider HTTP clients and resilience to WebClient

**Files:**
- Modify `src/main/java/com/incode/verification/config/provider/ProviderHttpConfiguration.java`.
- Modify `src/main/java/com/incode/verification/config/provider/ProviderResilienceConfiguration.java`.
- Modify `src/main/java/com/incode/verification/config/provider/DistributedProviderResilienceConfiguration.java`.
- Modify `src/main/java/com/incode/verification/client/TypedProviderClient.java`.
- Modify `src/main/java/com/incode/verification/client/FreeProviderClient.java`.
- Modify `src/main/java/com/incode/verification/client/PremiumProviderClient.java`.
- Modify `src/main/java/com/incode/verification/client/DistributedFreeProviderClient.java`.
- Modify `src/main/java/com/incode/verification/client/DistributedPremiumProviderClient.java`.
- Modify `src/main/java/com/incode/verification/service/ProviderService.java`.
- Modify `src/test/java/com/incode/verification/client/TypedProviderClientTest.java`.
- Modify `src/test/java/com/incode/verification/client/DistributedProviderClientTest.java`.
- Modify `src/test/java/com/incode/verification/service/ProviderServiceTest.java`.

**Interfaces:**
- `TypedProviderClient.lookup` returns `Mono<ProviderResult>`.
- `ProviderService.resolve` returns `Mono<ProviderResult>`.
- Resilience decorators wrap a `Mono<ProviderResult>` without blocking or waiting on a semaphore.

- [ ] **Step 1: Write failing WebClient provider tests**

Use a Reactor Netty mock server or `MockWebServer` and verify:

```java
StepVerifier.create(client.lookup(query))
    .assertNext(result -> assertInstanceOf(ProviderResult.Success.class, result))
    .verifyComplete();
StepVerifier.create(client.lookup(queryWithTimeout))
    .expectError(ProviderTransientException.class)
    .verify();
```

Cover successful typed mapping, 4xx client error, malformed payload,
connection failure, response timeout, and free-to-premium fallback.

- [ ] **Step 2: Configure Reactor Netty WebClient resources**

Create a `ConnectionProvider` with the existing total/per-route intent and an
`HttpClient` with connect, response, acquisition, and idle eviction settings.
Build provider-specific `WebClient` instances with the existing base URL, path,
and API-key behavior. Use `responseTimeout` and map timeout exceptions to the
existing `ProviderFailure.Timeout` model.

- [ ] **Step 3: Implement reactive response mapping and error classification**

Use `retrieve().onStatus(...)` and `bodyToMono(responseType)`; map response
arrays with the existing provider mappers. Preserve the current rules:

```text
4xx -> ProviderFailure.ClientError
timeout -> ProviderFailure.Timeout
connection/5xx/decode failure -> ProviderFailure.Unavailable or Malformed
```

Return domain failures where the current client returns a failure result and
propagate only exceptions that the resilience layer is configured to retry.

- [ ] **Step 4: Apply Reactor Resilience4j operators**

Compose the provider publisher with the existing `Retry`, `CircuitBreaker`,
`RateLimiter`, and `Bulkhead` instances using Reactor operators. Keep zero wait
for the provider bulkhead and preserve fallback conversion to `ProviderResult`.
Do not call `.block()`, `.toFuture().get()`, or a synchronous Resilience4j
decorator.

- [ ] **Step 5: Run provider tests and commit**

```bash
./gradlew test --tests com.incode.verification.client.TypedProviderClientTest --tests com.incode.verification.client.DistributedProviderClientTest --tests com.incode.verification.service.ProviderServiceTest
git add src/main/java/com/incode/verification/client src/main/java/com/incode/verification/config/provider src/main/java/com/incode/verification/service/ProviderService.java src/test/java/com/incode/verification/client src/test/java/com/incode/verification/service/ProviderServiceTest.java
git commit -m "feat: migrate provider clients to WebClient"
```

---

### Task 5: Convert local/distributed coordination, leases, and rate limits

**Files:**
- Modify `src/main/java/com/incode/verification/repository/coordination/LocalCoordinationRepository.java`.
- Modify `src/main/java/com/incode/verification/repository/coordination/RedisCoordinationRepository.java`.
- Modify `src/main/java/com/incode/verification/repository/coordination/RedisLease.java`.
- Modify `src/main/java/com/incode/verification/repository/coordination/LocalExpirationLock.java`.
- Modify `src/main/java/com/incode/verification/repository/coordination/RedisExpirationLock.java`.
- Modify `src/main/java/com/incode/verification/repository/ratelimit/RedisProviderRateLimiter.java`.
- Modify `src/main/java/com/incode/verification/repository/ratelimit/RedisInboundRateLimiter.java`.
- Modify `src/main/java/com/incode/verification/repository/ratelimit/Resilience4jInboundRateLimiter.java`.
- Modify `src/main/java/com/incode/verification/config/coordination/CoordinationConfiguration.java`.
- Modify `src/main/java/com/incode/verification/config/coordination/LocalCoordinationConfiguration.java`.
- Modify `src/main/java/com/incode/verification/config/coordination/ExpirationLockConfiguration.java`.
- Modify `src/main/java/com/incode/verification/config/ratelimit/InboundRateLimitConfiguration.java`.
- Modify Redis and local coordination/rate-limit tests.

**Interfaces:**
- `ReactiveStringRedisTemplate` is the only distributed Redis template.
- Every Redis operation returns a Reactor publisher.
- `Lease.release()` is idempotent and completes after the release operation.

- [ ] **Step 1: Write failing reactive coordination and rate-limit tests**

Use `StepVerifier` to assert acquired, unavailable, degraded, cache hit/miss,
release-once, Lua allow/reject, Redis failure, and local contention behavior.
Add a cancellation test proving a lease is released when the owner publisher is
cancelled.

- [ ] **Step 2: Convert local coordination without lock waiting**

Keep `tryLock()` semantics for immediate ownership decisions. Return
`Mono.just(...)` for local cache/lease operations and implement an idempotent
`Mono<Void> release()` that unlocks only when the lease owns the lock. Never use
`lock()`, `sleep`, or a blocking queue.

- [ ] **Step 3: Convert Redis coordination and lease scripts**

Use `ReactiveStringRedisTemplate.opsForValue()` and reactive script execution
for get/put/acquire/release. Preserve the existing key names, TTLs, JSON codec,
takeover behavior, and fail-closed degraded state. Map Redis errors to the same
degraded/unavailable outcomes as the synchronous implementation.

- [ ] **Step 4: Convert inbound and provider rate limiting**

Use a synchronous in-memory permit decision wrapped in `Mono.just` for the
single-node implementation. Use reactive Redis Lua execution for distributed
fixed-window decisions. Return `503` decisions for Redis unavailability and
retain `Retry-After` durations.

- [ ] **Step 5: Run coordination and Redis tests**

```bash
./gradlew test --tests com.incode.verification.repository.coordination.LocalCoordinationRepositoryTest --tests com.incode.verification.repository.coordination.RedisCoordinationRepositoryTest --tests com.incode.verification.repository.coordination.RedisExpirationLockTest --tests com.incode.verification.repository.ratelimit.Resilience4jInboundRateLimiterTest
./gradlew integrationTest --tests com.incode.verification.adapter.out.ratelimit.RedisProviderRateLimiterIntegrationTest --no-parallel --max-workers=1
```

Expected: local tests pass without waiting threads; Redis Testcontainers prove
the scripts and fail-closed behavior.

- [ ] **Step 6: Commit reactive coordination and limiting**

```bash
git add src/main/java/com/incode/verification/repository/coordination src/main/java/com/incode/verification/repository/ratelimit src/main/java/com/incode/verification/config/coordination src/main/java/com/incode/verification/config/ratelimit src/test/java/com/incode/verification/repository src/integrationTest/java/com/incode/verification/adapter/out/ratelimit
git commit -m "feat: migrate coordination and rate limiting to reactive Redis"
```

---

## File map and responsibilities

### Service build and runtime configuration

- Modify `company-check-service/build.gradle.kts`: reactive implementation/test dependencies and removal of blocking provider dependencies.
- Modify `company-check-service/gradle/libs.versions.toml`: catalog aliases for WebFlux, R2DBC, PostgreSQL R2DBC, Reactor test, and Resilience4j Reactor.
- Regenerate `company-check-service/gradle/verification-metadata.xml` through the existing Gradle verification workflow after dependency resolution.
- Modify `company-check-service/src/main/resources/application.yml`: R2DBC pool, Flyway/JDBC startup, provider WebClient, and virtual-thread settings.
- Modify `company-check-service/src/main/resources/application-distributed.yml`: reactive Redis connection/pool settings.
- Modify `company-check-service/src/main/resources/application-single-node.yml`: reactive local profile settings and removal of MVC/JDBC assumptions.
- Modify `company-check-service/src/main/java/com/incode/verification/config/persistence/PersistenceConfiguration.java`: R2DBC client and transaction beans.
- Modify `company-check-service/src/main/java/com/incode/verification/config/provider/ProviderHttpConfiguration.java`: WebClient/Reactor Netty resources and timeouts.
- Modify `company-check-service/src/main/java/com/incode/verification/config/provider/ProviderResilienceConfiguration.java` and `DistributedProviderResilienceConfiguration.java`: reactive provider bean wiring.
- Modify `company-check-service/src/main/java/com/incode/verification/config/coordination/CoordinationConfiguration.java` and `LocalCoordinationConfiguration.java`: reactive Redis/local implementations.
- Modify `company-check-service/src/main/java/com/incode/verification/config/coordination/ExpirationLockConfiguration.java`: reactive lease wiring.
- Modify `company-check-service/src/main/java/com/incode/verification/config/ratelimit/InboundRateLimitConfiguration.java`: reactive limiter wiring.

### Reactive ports and services

- Modify `src/main/java/com/incode/verification/repository/VerificationRepository.java`: reactive persistence signatures.
- Modify `src/main/java/com/incode/verification/repository/CoordinationRepository.java`: reactive lease and cache signatures.
- Modify `src/main/java/com/incode/verification/repository/ExpirationLock.java`: asynchronous lease release.
- Modify `src/main/java/com/incode/verification/repository/InboundRateLimiter.java`: `Mono<Decision>` admission.
- Modify `src/main/java/com/incode/verification/repository/ratelimit/ProviderRateLimiter.java`: `Mono<Boolean>` acquisition.
- Modify `src/main/java/com/incode/verification/client/ProviderClient.java`: `Mono<ProviderResult>` lookup.
- Modify `src/main/java/com/incode/verification/service/VerificationService.java`, `ProviderService.java`, `VerificationStoreService.java`, `VerificationRecoveryService.java`, and `ExpirationService.java`: reactive composition and transaction boundaries.

### Reactive adapters

- Replace `JdbcVerificationRepository.java` with `R2dbcVerificationRepository.java` using `DatabaseClient` and existing SQL.
- Modify `LocalCoordinationRepository.java`, `RedisCoordinationRepository.java`, `RedisLease.java`, `LocalExpirationLock.java`, and `RedisExpirationLock.java` for asynchronous lease/cache behavior.
- Modify `RedisProviderRateLimiter.java` and `RedisInboundRateLimiter.java` for reactive Lua execution.
- Modify `Resilience4jInboundRateLimiter.java` to expose a reactive decision without introducing waits.
- Modify `TypedProviderClient.java`, `FreeProviderClient.java`, `PremiumProviderClient.java`, `DistributedFreeProviderClient.java`, and `DistributedPremiumProviderClient.java` for WebClient and Reactor Resilience4j.

### Web layer and scheduler

- Modify `VerificationController.java` and `BackendServiceController.java` to return `Mono<ResponseEntity<...>>`.
- Replace `InboundRateLimitFilter.java` with a WebFlux `WebFilter` implementation.
- Adapt `GlobalExceptionHandler.java` for WebFlux validation and reactive exceptions while preserving `ProblemDetail` output.
- Modify `VerificationExpirationScheduler.java` for a nonblocking scheduled publisher with non-overlapping drains.

### Tests and workspace

- Update affected unit tests under `src/test/java/com/incode/verification` to use `Mono`, `Flux`, and `StepVerifier`.
- Replace JDBC integration tests with R2DBC integration tests under `src/integrationTest/java/com/incode/verification/adapter/out/persistence`.
- Update Redis test slices and integration tests to reactive templates and `StepVerifier`.
- Add reactive WebFlux controller/filter tests and architecture rules.
- Update `company-check-workspace/compose.yaml`, `mise.toml`, `README.md`, and architecture docs only where the reactive image/configuration requires it.
- Add benchmark results under the existing performance documentation location after the load run.

---

### Task 1: Create the service feature branch and reactive dependency baseline

**Files:**
- Create branch in `company-check-service`.
- Modify `company-check-service/build.gradle.kts`.
- Modify `company-check-service/gradle/libs.versions.toml`.
- Modify `company-check-service/src/main/resources/application.yml`.
- Modify `company-check-service/src/main/resources/application-distributed.yml`.
- Modify `company-check-service/src/main/resources/application-single-node.yml`.
- Modify `company-check-service/src/test/java/com/incode/verification/config/GradleStructureTest.java` and `RuntimeProfileConfigurationTest.java`.

**Interfaces:**
- Produces the dependency/runtime baseline consumed by every later task.
- The service branch must be named `feat/webflux-reactive`.

- [ ] **Step 1: Create the service branch and verify both checkouts are clean**

```bash
cd company-check-service
git status --short --branch
git switch -c feat/webflux-reactive
git status --short --branch
```

Expected: the service branch is `feat/webflux-reactive` and no pre-existing files are modified.

- [ ] **Step 2: Add reactive dependency aliases and remove provider HTTP blocking dependencies**

Add catalog aliases for:

```toml
spring-boot-starter-webflux = { module = "org.springframework.boot:spring-boot-starter-webflux" }
spring-boot-starter-webflux-test = { module = "org.springframework.boot:spring-boot-starter-webflux-test" }
spring-boot-starter-data-r2dbc = { module = "org.springframework.boot:spring-boot-starter-data-r2dbc" }
r2dbc-postgresql = { module = "org.postgresql:r2dbc-postgresql" }
r2dbc-pool = { module = "io.r2dbc:r2dbc-pool" }
reactor-test = { module = "io.projectreactor:reactor-test" }
resilience4j-reactor = { module = "io.github.resilience4j:resilience4j-reactor", version.ref = "resilience4j" }
```

In `build.gradle.kts`, use `spring-boot-starter-webflux`,
`spring-boot-starter-data-r2dbc`, `r2dbc-pool`, and
`resilience4j-reactor`. Keep the JDBC/PostgreSQL/Flyway dependencies only when
needed by startup migrations. Remove `httpclient5`,
`spring-boot-starter-webmvc-test`, and synchronous provider HTTP dependencies.
Use `spring-boot-starter-webflux-test` and `reactor-test` for tests.

- [ ] **Step 3: Add R2DBC and Flyway connection properties without changing Compose credentials**

Add properties with the same environment values used by the current Compose
stack:

```yaml
spring:
  r2dbc:
    url: ${SPRING_R2DBC_URL:r2dbc:postgresql://localhost:5432/company_check}
    username: ${SPRING_R2DBC_USERNAME:company_check}
    password: ${SPRING_R2DBC_PASSWORD:change-me-locally}
    pool:
      enabled: true
      initial-size: 4
      min-idle: 4
      max-size: 16
      max-acquire-time: 250ms
      max-create-connection-time: 150ms
      max-life-time: 1500s
```

Retain JDBC/Flyway properties for startup migration compatibility and keep the
existing provider timeout values. Remove `spring.threads.virtual.enabled` from
the reactive branch configuration.

- [ ] **Step 4: Run dependency resolution and the configuration tests**

```bash
./gradlew dependencies --configuration runtimeClasspath --write-verification-metadata sha256
./gradlew test --tests com.incode.verification.config.GradleStructureTest --tests com.incode.verification.config.RuntimeProfileConfigurationTest
```

Expected: Gradle resolves WebFlux/R2DBC/Reactor dependencies, verification
metadata is updated only for those artifacts, and configuration tests pass.

- [ ] **Step 5: Commit the baseline**

```bash
git add build.gradle.kts gradle/libs.versions.toml gradle/verification-metadata.xml src/main/resources/application*.yml src/test/java/com/incode/verification/config/GradleStructureTest.java src/test/java/com/incode/verification/config/RuntimeProfileConfigurationTest.java
git commit -m "build: add reactive service dependencies"
```

---

### Task 9: Make the local stack run the reactive image and preserve observability

**Files:**
- Modify `compose.yaml` only for R2DBC/Flyway environment variables required by the backend container.
- Modify `.env.example` only for a distinct optional reactive image tag if needed.
- Modify `scripts/mise-setup.sh` to accept the selected service image tag for both the Gradle image build and Compose startup.
- Modify `mise.toml` to add reactive build/start/load/check commands without changing existing commands.
- Modify `README.md` and relevant `docs/architecture/*.md` to document the reactive branch commands and runtime distinction.
- Modify `observability/grafana/provisioning/dashboards/company-check-overview.json` only to add R2DBC pool/event-loop panels while retaining existing panels.

**Interfaces:**
- Existing `mise run setup-all`, `mise run load-observability`, and `mise run observability-check` remain valid for the current branch.
- Add explicit reactive commands that select the reactive image, for example `setup-reactive-all` and `load-reactive-observability`, without overwriting the current image tag.

- [ ] **Step 1: Add the R2DBC container environment**

Add backend environment values equivalent to:

```yaml
SPRING_R2DBC_URL: "r2dbc:postgresql://postgres:5432/${COMPANY_CHECK_DB_NAME:-company_check}"
SPRING_R2DBC_USERNAME: "${COMPANY_CHECK_DB_USER:-company_check}"
SPRING_R2DBC_PASSWORD: "${COMPANY_CHECK_DB_PASSWORD:-change-me-locally}"
```

Retain the JDBC/Flyway values if startup migration support needs them.

- [ ] **Step 2: Add reactive image workflow commands**

Use the existing service-local Gradle invocation and image variant contract. Add
`service_image="${COMPANY_CHECK_SERVICE_IMAGE:-company-check-service:local}"` to
`scripts/mise-setup.sh`, pass `-PimageName="$service_image"` to Gradle, and
print/use the same image name for Compose startup.

```toml
[tasks.setup-reactive-all]
description = "Build and start the WebFlux reactive observability stack"
run = "COMPANY_CHECK_SERVICE_IMAGE=company-check-service:reactive-local scripts/mise-setup.sh \"${IMAGE_VARIANT:-jvm}\" --observability"

[tasks.load-reactive-observability]
description = "Load the WebFlux reactive stack with at least 10,000 requests"
run = "COMPANY_CHECK_SERVICE_IMAGE=company-check-service:reactive-local PERFORMANCE_REQUESTS=10000 PERFORMANCE_REQUESTS_AT_LEAST=true PERFORMANCE_USERS=20 PERFORMANCE_SPAWN_RATE=5 PERFORMANCE_DURATION=15m PERFORMANCE_COMPOSE_PROJECT_NAME=company-check-reactive PERFORMANCE_KEEP_STACK=true PERFORMANCE_OBSERVABILITY=true company-check-service/performance/run.sh"
```

Use the repository's existing setup runner rather than introducing a second
Compose orchestration path. Ensure native selection still works through
`IMAGE_VARIANT=native`.

- [ ] **Step 3: Add dashboard panels for reactive resources**

Keep request rate, error rate, p95, heap, CPU, logs, and traces. Add or update
panels for R2DBC pool active/idle/pending metrics and Reactor Netty connection
pool/event-loop metrics when exposed by Actuator. Do not remove useful current
panels without an equivalent replacement.

- [ ] **Step 4: Validate Compose and dashboard provisioning**

```bash
mise run compose-check
docker compose -f compose.yaml -f compose.single.yaml -f compose.observability.yaml --profile observability config >/dev/null
```

Expected: Compose resolves all reactive environment values and Grafana still
provisions the Company Check dashboard.

- [ ] **Step 5: Commit workspace workflow changes**

```bash
git add compose.yaml .env.example scripts/mise-setup.sh mise.toml README.md docs/architecture observability/grafana/provisioning/dashboards/company-check-overview.json
git commit -m "build: add reactive observability workflow"
```

---

### Task 10: Run complete JVM/native verification and update the workspace pointer

**Files:**
- Modify workspace submodule entry `company-check-service` by recording the service feature commit.
- Create/modify `docs/performance/webflux-reactive-comparison.md` with measured results.

**Interfaces:**
- Workspace branch `feat/webflux-reactive` points to service branch `feat/webflux-reactive`.
- The comparison document records commands, versions, load shape, results, and limitations without claiming an unmeasured win.

- [ ] **Step 1: Run the complete service quality gate**

```bash
./company-check-service/gradlew -p company-check-service qualityGate --no-parallel --max-workers=1
```

Expected: formatting, Checkstyle, static analysis, unit tests, coverage,
integration tests, and contract tests pass with the reactive implementation.

- [ ] **Step 2: Build and start the JVM reactive image**

```bash
IMAGE_VARIANT=jvm mise run setup-reactive-all
mise run health
```

Expected: the reactive backend is healthy and the provider/database stack is
running.

- [ ] **Step 3: Verify persistence and observability before load**

```bash
mise run smoke
mise run observability-check
```

Expected: the smoke verification is retrievable from PostgreSQL and Grafana,
Prometheus, Loki, and Tempo are reachable.

- [ ] **Step 4: Run at least 10,000 Locust requests**

```bash
mise run load-reactive-observability
```

Expected: at least 10,000 completed load requests, no unexpected error spike,
the stack remains available, and verification rows increase in PostgreSQL.

- [ ] **Step 5: Verify post-load observability and data**

```bash
mise run observability-check
docker compose -f compose.yaml -f compose.single.yaml -f compose.observability.yaml --profile observability exec -T postgres psql -U "${COMPANY_CHECK_DB_USER:-company_check}" -d "${COMPANY_CHECK_DB_NAME:-company_check}" -Atc 'select count(*) from verifications'
```

Record request count, errors, latency, RSS, CPU, R2DBC pool, provider
concurrency, event-loop metrics, persisted rows, dashboard state, and trace
availability in `docs/performance/webflux-reactive-comparison.md`.

- [ ] **Step 6: Build and start the native reactive image**

```bash
IMAGE_VARIANT=native mise run setup-reactive-all
mise run health
```

Expected: native image compilation, startup, health, smoke, and observability
checks pass. If native compilation exposes missing reachability metadata, add
the concrete hint and rerun Task 8 before continuing.

- [ ] **Step 7: Commit the service implementation and workspace pointer**

In the service submodule:

```bash
git status --short --branch
git log -1 --oneline
git push -u origin feat/webflux-reactive
```

In the workspace:

```bash
git add company-check-service docs/performance/webflux-reactive-comparison.md
git commit -m "feat: add WebFlux reactive service variant"
git push -u origin feat/webflux-reactive
```

Expected: both feature branches are pushed, the workspace points to the
reactive service commit, and neither `main` branch is changed.

---

## Plan self-review checklist

- Spec coverage: architecture/data flow is covered by Tasks 2–7; dependencies
  and runtime are covered by Tasks 1 and 8; observability is covered by Tasks 8–10;
  tests are attached to every boundary; benchmark and delivery are covered by
  Tasks 9–10.
- Blocking boundary coverage: JDBC, synchronous Redis, RestClient, servlet
  filter, blocking scheduler, `.block()`, and Apache HTTP client checks are
  explicitly covered by Tasks 1, 7, and 8.
- Type consistency: `Mono<ProviderResult>`, reactive repository methods,
  `Mono<Decision>`, reactive leases, and `TransactionalOperator` are defined
  before the tasks that consume them.
- Placeholder scan: the plan contains no `TODO`, `TBD`, or unassigned design
  decisions. Every task has exact files, commands, expected verification, and a
  commit boundary.
- Integration boundary: the service branch is implemented first; the workspace
  pointer and workflow changes are applied only after service verification.
