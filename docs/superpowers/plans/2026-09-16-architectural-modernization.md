# Architectural & Structural Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verify and harden the existing Company Check modernization while preserving API, provider, persistence, and deployment contracts.

**Architecture:** Keep `configuration` as the Spring composition root, `application` dependent only on ports and domain, adapters dependent on application ports, and the domain framework-free. PostgreSQL remains authoritative; Redis/Caffeine provide coordination, leasing, rate limiting, and caching only.

**Tech Stack:** Java 25, Spring Boot 4.1, Spring Modulith, Gradle Kotlin DSL, JdbcClient/JDBC, PostgreSQL, Redis, Apache HttpClient 5, Resilience4j, Caffeine, Testcontainers, ArchUnit, Bun/Fastify provider, Docker Compose, Mermaid.

**Status:** Implementation and verification complete; service changes remain in the existing mixed worktree for review, and isolated documentation corrections are committed.

## Global Constraints

- Keep `GET /backend-service` and `GET /verifications/{verificationId}` behavior aligned with the OpenAPI contract and controller implementation.
- Keep the domain free of Spring, HTTP, JDBC, Redis, caching, and other infrastructure dependencies.
- Keep application services dependent on application ports and domain types; keep concrete adapter and infrastructure dependencies at configuration or adapter boundaries.
- PostgreSQL is authoritative for verification identity, status, expiry, and terminal results. Redis and Caffeine may coordinate, lease, rate-limit, or cache, but cannot become the source of verification truth.
- Preserve provider route shapes, deterministic fixtures, scenario ordering, health routes, and the Bun/Fastify provider boundary.
- Keep scarce resources explicitly bounded: database connections, Redis pool resources, provider HTTP connections, provider concurrency, and rate limits.
- Use tests before behavior changes. Do not remove or weaken existing tests or JaCoCo/quality gates.
- Preserve unrelated worktree changes and do not reset, discard, or silently overwrite pending edits.
- Do not stage the parent submodule pointer unless the service repository change is intentionally complete and reviewed.

## Baseline

Run from `company-check-service/`:

```bash
./gradlew fastCheck --no-daemon --console=plain
```

Observed baseline: `BUILD SUCCESSFUL`; 24 tasks, with unit tests, formatting,
Checkstyle, coverage verification, and static checks passing.

## File map

### Boundary and configuration verification

- Modify: `company-check-service/src/test/java/com/incode/verification/architecture/HexagonalDependencyTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/architecture/DomainPackageStructureTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/architecture/AdapterPackageStructureTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/configuration/RuntimeProfileConfigurationTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/configuration/GradleStructureTest.java`
- Modify: `company-check-service/src/main/java/com/incode/verification/configuration/*.java` only when a failing test identifies a configuration defect.

### Persistence and coordination verification

- Modify: `company-check-service/src/test/java/com/incode/verification/application/VerificationUseCaseServiceTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/application/VerificationRecoveryIT.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/adapter/out/persistence/JdbcVerificationRepositoryIntegrationTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/adapter/out/coordination/RedisCoordinationAdapterTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/adapter/out/coordination/RedisExpirationLockTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/adapter/out/coordination/LocalExpirationLockTest.java` only if the existing scheduler/lock coverage is incomplete.
- Modify: application or adapter production files only after a red test demonstrates a defect.

### Provider and resource verification

- Modify: `company-check-service/src/test/java/com/incode/verification/adapter/out/provider/ProviderPropertiesTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/adapter/out/provider/ProviderResponseMapperTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/adapter/out/provider/DistributedProviderTest.java`
- Create or modify: `company-check-service/src/test/java/com/incode/verification/configuration/ProviderHttpConfigurationTest.java`
- Modify: `company-check-service/src/main/java/com/incode/verification/configuration/ProviderHttpConfiguration.java` only when configuration tests identify a defect.
- Modify: `company-check-service/src/main/resources/application.yml` only when the resource-bound tests or contract checks identify a mismatch.

### Contract and documentation

- Modify: `company-check-service/src/test/java/com/incode/verification/adapter/in/web/BackendServiceControllerTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/configuration/IncodeCompositionTest.java`
- Modify: `openapi/backend-api.yaml` only if controller and contract parity fails.
- Modify: `README.md`, `.env.example`, `compose.yaml`, `compose.single.yaml`, `compose.distributed.yaml`, `mise.toml` only when rendered configuration or command documentation is inconsistent.
- Modify: `docs/README.md`, `docs/adr/README.md`, and `docs/architecture/README.md` for index/link consistency.
- Modify: `docs/adr/0001-hexagonal-modulith.md` through `docs/adr/0008-testcontainers-docker-context.md` only to correct factual inconsistencies; do not rewrite accepted decisions silently.
- Modify: `docs/architecture/overview.md`, `request-flow.md`, `expiration-flow.md`, `deployment.md`, and `testing.md` to match verified implementation behavior.

## Task 1: Establish architecture and configuration red tests

**Files:**

- Test: the architecture and configuration test files listed in the boundary map above.
- Source: no production source changes in the red phase.

**Interfaces:**

- Consumes: current package tree, Spring profile configuration, Gradle convention plugins, and existing tests.
- Produces: executable assertions for the target package graph and runtime profile/resource invariants.

- [x] **Step 1: Inspect existing assertions and add only missing invariants**

Add focused tests for these exact behaviors. Use ArchUnit’s existing imported
`noClasses()` rule style in `HexagonalDependencyTest` and preserve the current
JUnit test names/conventions:

| Test | Required assertion |
|---|---|
| `domainDoesNotDependOnSpringOrInfrastructure` | No class in `..verification.domain..` depends on `org.springframework..`, `org.apache.hc..`, `org.springframework.data.redis..`, `javax.sql..`, or `java.sql..`. |
| `adaptersDependOnApplicationPortsInsteadOfConfiguration` | No class in `..verification.adapter..` depends on `..verification.configuration..`. |
| `configurationOwnsConcreteAdapterWiring` | Concrete provider, persistence, coordination, and rate-limit implementations are reachable from configuration tests, not application services. |

Adapt the snippets to the project’s existing ArchUnit style and avoid
duplicating an assertion already present. Add profile assertions that local
configuration supplies local coordination and distributed configuration
supplies Redis coordination, while both profiles retain PostgreSQL access.

- [x] **Step 2: Run the focused tests and record the red result**

Run:

```bash
./gradlew test --tests '*HexagonalDependencyTest' --tests '*DomainPackageStructureTest' --tests '*AdapterPackageStructureTest' --tests '*RuntimeProfileConfigurationTest'
```

Expected: existing assertions pass; any new assertion that exposes a real
violation fails with the concrete class/package name. If all tests pass, keep
the tests as regression coverage and proceed without production changes.

- [x] **Step 3: Implement the minimum boundary/configuration correction**

If red, change only the named import, package declaration, bean condition, or
profile property that caused the failure. Do not move application behavior or
introduce a wrapper solely to satisfy the test.

- [x] **Step 4: Run the focused tests green**

```bash
./gradlew test --tests '*HexagonalDependencyTest' --tests '*DomainPackageStructureTest' --tests '*AdapterPackageStructureTest' --tests '*RuntimeProfileConfigurationTest'
```

Expected: all selected tests pass with zero failures and zero skipped tests.

- [ ] **Step 5: Commit the task**

```bash
git add src/main src/test
git diff --cached --check
git commit -m "test(architecture): enforce modernization boundaries"
```

Stage only this task’s tests and any directly required production hunk.

The service worktree already contained unrelated modernization edits before
this task. Keep this commit pending until those edits are separated and
reviewed; do not stage the whole service tree.

## Task 2: Verify PostgreSQL authority and coordination safety

**Files:**

- Test: application, persistence, Redis coordination, expiration lock, and recovery tests listed above.
- Source: only the directly implicated application/adapter class after a red test.

**Interfaces:**

- Consumes: `VerificationRepository`, `CoordinationPort`, `ExpirationLock`, and existing application services.
- Produces: regression coverage proving read/write authority, duplicate-work coordination, safe lease ownership, and recovery semantics.

- [x] **Step 1: Review existing authority/lease coverage and add only uncovered invariants**

Cover these exact cases using the existing `MemoryRepository`, coordination
fakes, Mockito Redis adapter tests, and Testcontainers integration tests:

| Test name | Setup and assertion |
|---|---|
| `retrievalReadsTheAuthoritativeRepositoryWithoutCallingCoordinationOrProvider` | Seed an in-progress or terminal row in `MemoryRepository`, call the retrieval use case, and assert the result comes from the row while provider and coordination call counters remain zero. |
| `conflictingVerificationIdIsReturnedBeforeProviderLookup` | Seed a terminal row with a different normalized query, call start with the same ID, assert `VerificationConflictException`, and assert provider calls remain zero. |
| `terminalRepositoryCommitPrecedesOptionalCoordinationPublication` | Use a recording repository and coordination fake, complete a verification, and assert the repository completion event precedes the coordination publication event. |
| `expirationLeaseCannotReleaseAnotherOwnerLease` | Exercise the Redis lease with a token mismatch, assert the release script is invoked, and assert the adapter does not report another owner’s lease as released. |

Each test must use a fake/spy for every external port and assert the single
behavior named by the test. Fill each test from the existing public methods;
do not invent a new API to make tests easier.

- [x] **Step 2: Run the tests and confirm the right failure**

```bash
./gradlew test --tests '*VerificationUseCaseServiceTest' --tests '*RedisCoordinationAdapterTest' --tests '*RedisExpirationLockTest' --tests '*VerificationRecoveryIT'
```

Expected: newly added tests fail only where implementation violates the
authority/lease invariant; compilation failures count as red for a missing
test seam and must be resolved minimally.

- [x] **Step 3: Implement the minimum correction**

Correct ordering, SQL selection, lease token checking, or degraded behavior as
identified by the red test. Keep PostgreSQL as the state authority and retain
existing exception types and response mappings.

- [x] **Step 4: Run unit and integration coverage green**

```bash
./gradlew test --tests '*VerificationUseCaseServiceTest' --tests '*RedisCoordinationAdapterTest' --tests '*RedisExpirationLockTest'
./gradlew integrationTest --tests '*JdbcVerificationRepositoryIntegrationTest' --tests '*VerificationRecoveryIT'
```

Expected: selected unit tests pass. Integration tests require Docker; if Docker
is unavailable, preserve the evidence and report that environmental blocker.

- [ ] **Step 5: Commit the task**

```bash
git add src/main src/test src/integrationTest
git diff --cached --check
git commit -m "test(verification): protect authoritative state flow"
```

## Task 3: Verify provider HTTP pooling and resilience policies

**Files:**

- Test: provider and configuration tests listed in the provider map.
- Source: `ProviderHttpConfiguration.java`, provider adapters, or
  `application.yml` only when a red test proves the defect.

**Interfaces:**

- Consumes: provider endpoint properties, Apache HttpClient 5, provider lookup port, and Resilience4j configuration.
- Produces: tested provider boundary with explicit pool/timeouts and stable failure classification.

- [x] **Step 1: Review existing provider/configuration coverage and add only uncovered invariants**

Add focused tests with these exact names and assertions:

| Test name | Required assertion |
|---|---|
| `providerHttpClientUsesConfiguredPoolAndTimeoutBounds` | Build the configuration with the test properties, obtain the `CloseableHttpClient`, and assert the configured pool totals and request/connect/response timeout values through the supported client configuration API. |
| `contractFailuresAreNotClassifiedAsTransient` | Feed a 4xx response or malformed payload to `RestClientProviderAdapter` and assert a terminal `ProviderResult.Failure` or `ProviderContractException`, never `ProviderTransientException`. |
| `transientFailuresUseTheConfiguredRetryBoundary` | Feed a transient provider failure to the existing resilient provider seam and assert the configured provider retry policy is selected without changing the failure classification. |

Use the actual bean/property types exposed by the current implementation. Do
not test private implementation details when a bean or provider port can be
tested instead.

- [x] **Step 2: Run provider-focused tests red**

```bash
./gradlew test --tests '*ProviderPropertiesTest' --tests '*ProviderResponseMapperTest' --tests '*DistributedProviderTest' --tests '*ProviderHttpConfigurationTest'
```

Expected: new tests fail for each missing or incorrect invariant, or all pass
if the existing implementation already satisfies the design.

- [x] **Step 3: Implement only proven corrections**

Use the current Apache HttpClient 5 and Spring-supported configuration APIs.
Keep one shared bounded connection manager, explicit request/connect/response
deadlines, and existing Resilience4j policy names. Do not add a second HTTP
client abstraction.

- [x] **Step 4: Run focused checks green**

```bash
./gradlew test --tests '*ProviderPropertiesTest' --tests '*ProviderResponseMapperTest' --tests '*DistributedProviderTest' --tests '*ProviderHttpConfigurationTest'
```

Expected: all selected tests pass with no skipped tests.

- [ ] **Step 5: Commit the task**

```bash
git add src/main src/test
git diff --cached --check
git commit -m "test(provider): verify bounded resilient HTTP boundary"
```

## Task 4: Validate API, build, Compose, and runtime documentation

**Files:**

- Test: `BackendServiceControllerTest.java`, `IncodeCompositionTest.java`, and `GradleStructureTest.java`.
- Modify: root README, Compose files, `.env.example`, `mise.toml`, OpenAPI, and docs indexes/diagrams only when validation finds drift.

**Interfaces:**

- Consumes: Spring controllers, OpenAPI contract, Gradle tasks, Compose overlays, ADRs, and architecture documents.
- Produces: one internally consistent developer/release workflow and documentation set.

- [x] **Step 1: Review existing parity/documentation checks and add only uncovered invariants**

Cover these exact behaviors using the current controller, configuration, and
build-structure test styles:

| Test name | Required assertion |
|---|---|
| `backendServiceContractUsesGet` | The controller mapping and OpenAPI path both expose `GET /backend-service`; no POST mapping is present. |
| `distributedProfileRequiresRedisCoordination` | The distributed profile selects Redis coordination and Redis rate limiting while the single-node profile selects local/Resilience4j implementations. |
| `documentedServiceTasksExistInGradle` | Every service command documented in the root README resolves to a task or documented workspace alias. |

Use existing contract/build test conventions and compare actual parsed route or
configuration values rather than duplicating raw strings in assertions.

- [x] **Step 2: Run focused validation**

```bash
./gradlew test --tests '*BackendServiceControllerTest' --tests '*IncodeCompositionTest' --tests '*GradleStructureTest'
docker compose -f compose.yaml -f compose.single.yaml config
docker compose -f compose.yaml -f compose.distributed.yaml config
```

Expected: tests pass; both Compose commands render valid configurations. If
Docker is unavailable, run static YAML inspection and report the blocker.

- [x] **Step 3: Correct drift and complete documentation**

Ensure these documents are present and linked:

- `docs/adr/0001-hexagonal-modulith.md` through `0008-testcontainers-docker-context.md`
- `docs/architecture/overview.md`
- `docs/architecture/request-flow.md`
- `docs/architecture/expiration-flow.md`
- `docs/architecture/deployment.md`
- `docs/architecture/testing.md`

Update diagrams and commands to match verified behavior. Keep ADR decisions
immutable; use a new ADR when a decision genuinely changes. Do not claim a
performance threshold is enforced when the runner only reports it.

- [x] **Step 4: Run provider and workspace documentation checks**

```bash
(cd company-check-provider && bun run quality)
git diff --check
```

Expected: provider quality passes and the combined worktree has no whitespace
errors in changed text files.

- [x] **Step 5: Commit the task**

```bash
git add README.md .env.example compose.yaml compose.single.yaml compose.distributed.yaml mise.toml openapi/backend-api.yaml docs/adr docs/architecture
git diff --cached --check
git commit -m "docs(workspace): align architecture and deployment guidance"
```

Do not stage the provider or service submodule pointer in this commit.

Documentation corrections were committed as `fd113b1`; the baseline ADR and
architecture files were already tracked separately.

## Task 5: Run complete verification and close the plan

**Files:**

- Modify: this plan, updating each completed checkbox and the final status.
- No source changes unless verification exposes a new red test; add that test
  and correction as a new task before changing production code.

- [x] **Step 1: Run the fast service gate**

```bash
./gradlew fastCheck --no-daemon --console=plain
```

Expected: `BUILD SUCCESSFUL`, zero test failures, zero skipped tests, and
coverage verification passing.

- [x] **Step 2: Run the complete service gate**

```bash
./gradlew qualityGate --no-daemon --console=plain --no-parallel --max-workers=1
```

Expected: `BUILD SUCCESSFUL` with PostgreSQL/Redis integration tests and
contract checks passing. If Testcontainers cannot connect to Docker, preserve
the exact error and do not mark the integration portion complete.

- [x] **Step 3: Review the final dependency and contract surface**

```bash
tgrep -n 'adapter\.config|adapter\.out\.expiration|domain\.(aggregate|entity|policy|type|valueobject)|org\.springframework' company-check-service/src/main/java/com/incode/verification/domain company-check-service/src/main/java/com/incode/verification/application || true
git diff --check
git -C company-check-service status --short
git status --short
```

Expected: no legacy package references and no Spring imports in domain or
application packages; all remaining changes are intentional and reviewable.

- [x] **Step 4: Mark the plan complete and report evidence**

All available required checks pass. Service source changes remain intentionally
uncommitted because the nested repository had a pre-existing mixed worktree;
report the changed files and commits without claiming a clean service tree.
