# AI Rules Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Apply the downloaded AI rules to the approved Company Check workspace while preserving its API, topology, runtime choices, and repository boundaries.

**Architecture:** Keep the parent workspace as Compose and contract owner, the Java repository as the annotation-first Spring Modulith service, and the Bun/Fastify repository as the deterministic provider simulator. Add repository-local guidance that records the translated rules and explicit project exceptions, then enforce the highest-value rules through formatting, lint/type checks, static contract checks, and focused tests.

**Tech Stack:** Java 25, Spring Boot 4.1.1, Spring Modulith 2.1.1, Gradle, Spotless, Checkstyle, JDBC, PostgreSQL, Redis, Caffeine, Resilience4j 2.4.0, Bun 1.3.9, TypeScript 5.9, Fastify, Zod, ESLint, Docker Compose, Bats, Locust.

## Global Constraints

- Do not modify `/Users/miguelangeldelgadillozarate/Development/incode-test`.
- Preserve the assignment API and behavior exactly.
- Keep Java 25 and upgrade the service to the Spring Boot 4.1.x line; do not adopt runtime or library versions merely because they appear in `ai-rules-hub-main`.
- Keep `company-check-service` and `company-check-provider` as independent repositories and update only parent gitlinks in the workspace.
- Keep Docker Compose and Colima/Docker as the only container topology/runtime path.
- Keep JDBC instead of JPA because PostgreSQL/JdbcClient is an approved design decision.
- Keep Bun/Fastify instead of switching to the rule hub's generic Node/npm defaults.
- Keep framework-free domain records and sealed types; annotations belong at framework boundaries.
- Do not add speculative factories, registries, facades, mediators, meshes, or new infrastructure.
- Every behavior change must have a focused failing test or static contract check before implementation; formatting and documentation-only changes are exempt.

## Hard Acceptance Checklist

- Annotation-first Spring Boot API with Jakarta validation remains present at the HTTP boundary.
- Verification remains feature-oriented, with application ports separated from adapters.
- Domain records, sealed failures, and pure domain transformations remain framework-free.
- The canonical company contract remains exactly `cin`, `name`, `registrationDate`, `address`, and `isActive`.
- Resilience4j retry, circuit breaker, rate limiter, and bulkhead policies remain configured and applied to both providers.
- PostgreSQL remains the source of truth for idempotency, initial verification metadata, and terminal state.
- Redis remains the coordination/active-state and L2 cache layer; Caffeine remains the L1 cache with TTL and size bounds.
- The provider remains an independently deployable Bun/Fastify simulator with supplied fixtures and deterministic configurable failure sequences.
- Provider-compatible routes and smoke tests remain aligned with the assignment contract.
- Docker Compose remains the only composition topology and all image inputs remain digest-pinned.
- The JaCoCo focused unit coverage gate remains at least 80% for the included application/domain/API scope.

---

### Task 1: Translate rules into the Java service

**Files:**
- Create: `company-check-service/AGENTS.md`
- Modify: `company-check-service/src/main/java/com/incode/verification/adapter/out/persistence/JdbcVerificationRepository.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/architecture/HexagonalDependencyTest.java`
- Modify: `company-check-service/build.gradle.kts` only if a rule check is missing

**Interfaces:**
- Preserve all application ports, DTOs, HTTP paths, status codes, persistence schema, and provider contracts.
- `JdbcVerificationRepository.findById` must return the same rows using explicit selected columns rather than `SELECT *`.

- [ ] **Step 1:** Write a failing repository/architecture assertion that the persistence query names the required columns and the service guidance records JDBC/JPA and domain/framework exceptions.
- [ ] **Step 2:** Run the focused test/check and verify it fails for the existing `SELECT *` or missing guidance.
- [ ] **Step 3:** Add the concise service `AGENTS.md` and replace `SELECT *` with the explicit `verifications` columns.
- [ ] **Step 4:** Run the focused service tests and static checks; refactor only if all remain green.
- [ ] **Step 5:** Commit the service changes with `chore(rules): apply Java service standards`.

### Task 2: Translate rules into the Bun/Fastify provider

**Files:**
- Create: `company-check-provider/AGENTS.md`
- Modify: `company-check-provider/eslint.config.js`
- Modify: `company-check-provider/package.json`
- Modify: `company-check-provider/mise.toml`
- Modify: `company-check-provider/src/**/*.ts`
- Modify: `company-check-provider/test/**/*.ts`
- Modify: `company-check-provider/bun.lock` only through the selected formatter/linter dependency update

**Interfaces:**
- Preserve `/free-third-party`, `/premium-third-party`, health routes, fixture shapes, scenario file format, and deterministic behavior.
- Keep public functions explicitly typed and keep unknown input narrowed through Zod/type guards.

- [ ] **Step 1:** Add a failing lint rule/configuration assertion for explicit return types, unsafe `any`, and the provider formatting command.
- [ ] **Step 2:** Run the focused provider lint/format check and verify the current source/tests fail because of the compressed style or missing rules.
- [ ] **Step 3:** Add provider guidance, configure the smallest ESLint rule set compatible with Bun/Fastify, add a deterministic format/check script, and format source/tests without changing behavior.
- [ ] **Step 4:** Run provider lint, typecheck, tests, contract tests, and build; refactor only while green.
- [ ] **Step 5:** Commit the provider changes with `chore(rules): apply TypeScript provider standards`.

### Task 3: Translate rules into workspace contracts and tools

**Files:**
- Create: `AGENTS.md`
- Modify: `e2e/verification.bats`
- Modify: `e2e/provider-failures.bats`
- Modify: `performance/locustfile.py`
- Modify: `workspace-validate.sh`
- Modify: `README.md`
- Modify: `.github/workflows/release-jvm.yml` and `.github/workflows/release-native.yml` only to remove misleading placeholder steps or replace them with concrete, pinned checks

**Interfaces:**
- E2E and Locust clients must use `POST /backend-service` with `verificationId` and `query` query parameters.
- E2E expectations must match the canonical response fields (`cin`, `name`, `registrationDate`, `address`, `isActive`) and lifecycle statuses (`IN_PROGRESS`, `COMPLETED`, `FAILED`).
- Workspace validation must reject stale endpoint/field expectations and continue enforcing immutable image references, no fixed sleeps, and the single-node Compose topology.

- [ ] **Step 1:** Add failing workspace static assertions for stale GET/MATCH/NO_MATCH/legacy-field references in executable E2E and performance clients.
- [ ] **Step 2:** Run `workspace-validate.sh` and the focused shell/static checks to verify failure against the current stale clients.
- [ ] **Step 3:** Add workspace guidance, update Bats/Locust to the approved API, and make release workflow checks concrete or remove misleading placeholder steps.
- [ ] **Step 4:** Run workspace validation, shell syntax checks, OpenAPI validation, and the provider/service quality commands that do not require Docker.
- [ ] **Step 5:** Commit the workspace changes with `chore(rules): apply workspace engineering standards`.

### Task 4: Integrate and verify the three repositories

**Files:**
- Modify: parent gitlinks `company-check-service` and `company-check-provider`
- Modify: `.superpowers/sdd/progress.md` as scratch bookkeeping only; do not commit it

- [ ] **Step 1: Review each child diff and verify no child changes were made outside its task scope.
- [ ] **Step 2: Update only the parent gitlinks to the approved child commits.
- [ ] **Step 3: Run provider lint/typecheck/tests/build, service `qualityGate`, OpenAPI validation, workspace validation, shell syntax checks, and any available Compose smoke checks.
- [ ] **Step 4: Record Docker/Colima-dependent checks as blocked if the runtime is unavailable; do not claim them as passed.
- [ ] **Step 5:** Commit the parent pointer update with `chore(workspace): pin rule-compliant child revisions`.

### Task 5: Align the service with the approved Spring Boot baseline

**Files:**
- Modify: `company-check-service/gradle/libs.versions.toml`
- Modify: `company-check-service/build.gradle.kts`
- Modify: `company-check-service/gradle.lockfile`
- Modify: `company-check-service/settings-gradle.lockfile`
- Modify: `company-check-service/gradle/verification-metadata.xml`
- Modify: `company-check-service/src/test/java/com/incode/verification/configuration/IncodeCompositionTest.java` only if Boot 4.1 compatibility requires a test API adjustment

**Interfaces:**
- Keep Java toolchain language version 25.
- Set Spring Boot to the stable 4.1.x line and Spring Modulith to its Boot 4-compatible 2.1.x line.
- Replace the Boot 3-specific Resilience4j starter with the Boot 4-compatible starter at a released version that supports Spring Boot 4.
- Keep the existing API, database/cache design, resilience annotations, provider calls, Compose contract, and coverage threshold unchanged.

- [ ] **Step 1:** Add a failing version/baseline assertion that rejects Spring Boot 3.x, Modulith 1.x, and the Boot 3-specific Resilience4j starter while requiring Java 25.
- [ ] **Step 2:** Run the focused baseline check and capture the expected failure against the current catalog.
- [ ] **Step 3:** Upgrade to Spring Boot 4.1.x, Spring Modulith 2.1.x, and the released Resilience4j Boot 4 starter; regenerate dependency locks and verification metadata with the project’s existing Gradle tooling.
- [ ] **Step 4:** Run compilation, tests, Checkstyle, Spotless, architecture tests, JaCoCo gate, and OpenAPI validation; fix only Boot 4 compatibility issues without changing contracts.
- [ ] **Step 5:** Commit with `build(service): align with Spring Boot 4.1 and Java 25`.

## Review Checklist

- No placeholder rule text, `TODO`, stale API method, legacy response field, `SELECT *`, untyped public function, or unnecessary dependency remains in the changed scope.
- Service remains annotation-first at adapters and framework-free in the domain.
- Provider remains Bun/Fastify and scenario behavior remains deterministic.
- Parent remains a Compose-only workspace with one backend replica and no mesh/Kubernetes artifacts added.
- Validation results distinguish passing local checks from unavailable Docker-dependent checks.
