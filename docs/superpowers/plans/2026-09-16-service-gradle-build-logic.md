# Service Gradle Build Logic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract service Gradle configuration into organized convention plugins, add a fast local check path, remove duplicated service command aliases, and verify the existing requested service architecture remains intact.

**Architecture:** Use a single included `build-logic` build containing precompiled Kotlin convention plugins. The root service build retains only service-specific dependencies and image/provider properties; convention plugins own reusable Java, Spring, testing, quality, contract, and container task configuration.

**Tech Stack:** Gradle 9.0.0, Kotlin DSL, Java 25, Spring Boot 4.1.1, Spring Modulith 2.1.1, JDBC, PostgreSQL, Redis, Caffeine, Resilience4j, JaCoCo, Spotless, Checkstyle, Testcontainers, Redocly CLI, Docker/Paketo.

**Status:** Implemented. Docker-backed PostgreSQL integration remains pending
until the local Docker/Colima socket is available.

## Global Constraints

- Preserve the service HTTP paths, query parameters, status values, DTOs, persistence schema, provider wire contracts, and ports.
- Keep Java toolchain version 25 and Spring Boot 4.1.1.
- Keep the domain framework-free and keep annotations at HTTP/configuration/adapter boundaries.
- Keep JDBC/PostgreSQL as source of truth; Redis and Caffeine remain coordination/cache layers.
- Keep Resilience4j retry, circuit breaker, rate limiter, and bulkhead policies for both providers.
- Keep deterministic Bun/Fastify provider behavior and canonical response fields.
- Keep all image references digest-pinned and retain parent Compose ownership.
- Keep the focused JaCoCo line coverage minimum at 0.80.
- Do not delete parent workspace scripts; only remove duplicated service-local command aliases.

---

### Task 1: Add the included build-logic skeleton and Java/Spring conventions

**Files:**
- Create: `company-check-service/build-logic/settings.gradle.kts`
- Create: `company-check-service/build-logic/build.gradle.kts`
- Create: `company-check-service/build-logic/src/main/kotlin/com.incode.java-conventions.gradle.kts`
- Create: `company-check-service/build-logic/src/main/kotlin/com.incode.spring-boot-conventions.gradle.kts`
- Create: `company-check-service/build-logic/src/main/kotlin/com.incode.service-conventions.gradle.kts`
- Modify: `company-check-service/settings.gradle.kts`
- Modify: `company-check-service/build.gradle.kts`
- Test: `company-check-service/src/test/java/com/incode/verification/configuration/GradleStructureTest.java`

**Interfaces:**
- Produces plugin IDs `com.incode.java-conventions`, `com.incode.spring-boot-conventions`, and `com.incode.service-conventions`.
- `com.incode.service-conventions` applies Java and Spring conventions without changing dependency coordinates.

- [x] **Step 1: Write the failing static structure test.** Assert that `settings.gradle.kts` includes `build-logic`, the convention source files exist, and the root build applies `com.incode.service-conventions`.
- [x] **Step 2: Run the focused test and verify it fails** because the included build and plugin files do not yet exist.
- [x] **Step 3: Implement the minimal included build and convention plugins.** Use Gradle precompiled script plugins and preserve Java 25, Spotless, Checkstyle, Error Prone, and Spring Boot plugin application.
- [x] **Step 4: Run the focused test and `./gradlew help --configuration-cache`**; verify the task exits successfully and the plugin compiles.
- [x] **Step 5: Commit** with `build(service): add convention plugin build logic`.

### Task 2: Extract test, quality, and contract conventions

**Files:**
- Create: `company-check-service/build-logic/src/main/kotlin/com.incode.testing-conventions.gradle.kts`
- Create: `company-check-service/build-logic/src/main/kotlin/com.incode.quality-conventions.gradle.kts`
- Create: `company-check-service/build-logic/src/main/kotlin/com.incode.contract-conventions.gradle.kts`
- Modify: `company-check-service/build-logic/src/main/kotlin/com.incode.service-conventions.gradle.kts`
- Modify: `company-check-service/build.gradle.kts`
- Modify: `company-check-service/src/test/java/com/incode/verification/configuration/GradleStructureTest.java`

**Interfaces:**
- Produces `fastCheck`, `qualityGate`, `openApiValidate`, and the existing JVM test suites with unchanged names and behavior.
- `fastCheck` must not depend on integration/contract/E2E suites, OpenAPI CLI execution, or Docker tasks.

- [x] **Step 1: Add failing assertions** for task groups, `fastCheck` dependencies, and preservation of `qualityGate`/`openApiValidate`.
- [x] **Step 2: Run the focused test** and verify it fails against the monolithic build.
- [x] **Step 3: Move test suite, Spotless/Checkstyle, JaCoCo, OpenAPI, and quality task configuration** into the convention plugins; register `fastCheck` under `verification`.
- [x] **Step 4: Run `./gradlew tasks`, the focused test, and `./gradlew fastCheck --configuration-cache`**; verify organized groups and zero failures.
- [x] **Step 5: Commit** with `refactor(service): organize verification convention plugins`.

### Task 3: Extract container/image conventions and remove service command duplication

**Files:**
- Create: `company-check-service/build-logic/src/main/kotlin/com.incode.container-conventions.gradle.kts`
- Modify: `company-check-service/build-logic/src/main/kotlin/com.incode.service-conventions.gradle.kts`
- Modify: `company-check-service/build.gradle.kts`
- Delete: `company-check-service/mise.toml`
- Modify: `company-check-service/README.md` if command references require correction

**Interfaces:**
- Preserve `image`, `bootBuildImage`, `imageSmoke`, digest validation, JVM/native properties, and bounded smoke polling.
- No parent `scripts/*.sh` file is deleted or moved by this task.

- [x] **Step 1: Add a failing static assertion** that image tasks are supplied by the container convention and service `mise.toml` is absent.
- [x] **Step 2: Run the focused assertion** and verify it fails before extraction.
- [x] **Step 3: Move Paketo/image/imageSmoke logic** into the container convention plugin and remove the service `mise.toml` aliases.
- [x] **Step 4: Run `./gradlew tasks`, `./gradlew fastCheck`, and the image task configuration check without invoking Docker**; verify digest properties are still required only for image execution.
- [x] **Step 5: Commit** with `refactor(service): centralize container build conventions`.

### Task 4: Audit service contracts and apply only missing requested behavior

**Files:**
- Modify only service source/test files where the audit identifies a missing requirement.
- Test: the focused existing test file for each changed behavior.

**Interfaces:**
- Canonical company fields are exactly `cin`, `name`, `registrationDate`, `address`, and `isActive`.
- Lifecycle statuses are exactly `IN_PROGRESS`, `COMPLETED`, and `FAILED`.
- The provider routes remain `/free-third-party` and `/premium-third-party`.

- [x] **Step 1: Run focused static and unit checks** over annotations, records/sealed failures, persistence, resilience, cache/coordination, and provider mapping.
- [x] **Step 2: If a requirement is missing, write the smallest failing focused test first.** No missing behavior was found.
- [x] **Step 3: Implement only the missing behavior** without introducing JPA, framework annotations in domain code, or duplicate validation. No source changes were required.
- [x] **Step 4: Run the affected tests and `fastCheck`**; refactor while green.
- [x] **Step 5: Commit** with `fix(service): align audited contract behavior` only if changes were required. No commit was required.

### Task 5: Verify child and parent repository contracts

**Files:**
- Modify: parent gitlink `company-check-service` only after child commits are complete.
- Do not modify parent-owned service/provider source files directly.

- [x] **Step 1: Run service `fastCheck` and full `qualityGate` where dependencies are available.** Fast path passed; qualityGate reached the Docker-backed integration test and was blocked by the local Docker socket.
- [x] **Step 2: Run parent `workspace-validate.sh`, shell syntax checks, and available provider checks.**
- [x] **Step 3: Separate Docker/Colima-unavailable checks from passing checks.**
- [x] **Step 4: Update only the parent service gitlink if the child HEAD changed.**
- [x] **Step 5: Commit the parent pointer with `build(workspace): pin organized service build`** if needed.

## Definition of Done

- [x] `build-logic` is an included build with focused convention plugins.
- [x] Root service build is reduced to service-specific declarations.
- [x] `fastCheck` is fast and excludes external-service/container validation.
- [x] Full `qualityGate` and 80% focused JaCoCo gate remain available.
- [x] Service `mise.toml` duplication is removed; parent Compose scripts remain.
- [x] Requested service contracts are verified with evidence.
- [x] All changed files are committed in logical commits.
