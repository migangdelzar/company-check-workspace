# Verification Folder Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the Java service packages around business concepts and adapter responsibilities without changing runtime behavior.

**Architecture:** Keep the existing `domain`, `application`, and `adapter` boundaries. Replace generic domain taxonomy folders with concept folders, move Spring wiring into a top-level `configuration` package, place provider implementations under outbound adapters, and classify the expiration scheduler as an inbound adapter.

**Tech Stack:** Java 25, Spring Boot, Spring Modulith, Gradle, JDBC, Redis, Caffeine, JUnit 5, Google Java Format, Spotless.

## Global Constraints

- Preserve application ports, DTOs, HTTP contracts, persistence schema, and provider contracts.
- Keep domain records and sealed types framework-free.
- Use JDBC/JdbcClient for persistence. Do not introduce JPA or an ORM.
- PostgreSQL is the source of truth; use Redis/Caffeine only for coordination and caching.
- Do not change business logic, annotations, public methods, configuration keys, or external contracts.
- Move files with `git mv` so history remains discoverable.
- Do not stage unrelated existing changes in either repository.

---

## 1. File Map

All service implementation work happens in the nested repository
`company-check-service/`. The parent workspace receives this plan only; do not
stage the parent submodule pointer as part of the service migration.

### Domain moves

| Current path | Target path |
|---|---|
| `src/main/java/com/incode/verification/domain/aggregate/Verification.java` | `src/main/java/com/incode/verification/domain/verification/Verification.java` |
| `src/main/java/com/incode/verification/domain/entity/Company.java` | `src/main/java/com/incode/verification/domain/company/Company.java` |
| `src/main/java/com/incode/verification/domain/policy/FallbackPolicy.java` | `src/main/java/com/incode/verification/domain/provider/FallbackPolicy.java` |
| `src/main/java/com/incode/verification/domain/type/ProviderFailure.java` | `src/main/java/com/incode/verification/domain/provider/ProviderFailure.java` |
| `src/main/java/com/incode/verification/domain/type/ProviderResult.java` | `src/main/java/com/incode/verification/domain/provider/ProviderResult.java` |
| `src/main/java/com/incode/verification/domain/type/ProviderType.java` | `src/main/java/com/incode/verification/domain/provider/ProviderType.java` |
| `src/main/java/com/incode/verification/domain/type/VerificationState.java` | `src/main/java/com/incode/verification/domain/verification/VerificationState.java` |
| `src/main/java/com/incode/verification/domain/type/VerificationStatus.java` | `src/main/java/com/incode/verification/domain/verification/VerificationStatus.java` |
| `src/main/java/com/incode/verification/domain/valueobject/InvalidQueryException.java` | `src/main/java/com/incode/verification/domain/query/InvalidQueryException.java` |
| `src/main/java/com/incode/verification/domain/valueobject/NormalizedQuery.java` | `src/main/java/com/incode/verification/domain/query/NormalizedQuery.java` |
| `src/main/java/com/incode/verification/domain/valueobject/UuidV7.java` | `src/main/java/com/incode/verification/domain/identity/UuidV7.java` |

### Adapter and configuration moves

Move these provider implementation files from `adapter/config` to
`adapter/out/provider`:

- `DistributedFreeProvider.java`
- `DistributedPremiumProvider.java`
- `FreeProvider.java`
- `PremiumProvider.java`
- `ProviderRateLimitExceededException.java`
- `ResilientProvider.java`

Move `VerificationExpirationScheduler.java` from
`adapter/out/expiration` to `adapter/in/scheduling`.

Move every remaining file in `adapter/config` to the top-level
`configuration` package:

- `ApplicationConfiguration.java`
- `CacheConfiguration.java`
- `CoordinationConfiguration.java`
- `CoordinationProperties.java`
- `DatabaseProperties.java`
- `DatabaseRetryProperties.java`
- `DistributedProviderResilienceConfiguration.java`
- `LocalCoordinationConfiguration.java`
- `ObservabilityConfiguration.java`
- `PersistenceConfiguration.java`
- `ProviderHttpConfiguration.java`
- `ProviderRateLimitProperties.java`
- `ProviderResilienceConfiguration.java`
- `VerificationCacheExpiry.java`
- `VerificationProperties.java`

Move the package-private provider test so it remains beside the provider
implementation package:

```text
src/test/java/com/incode/verification/adapter/config/DistributedProviderTest.java
→ src/test/java/com/incode/verification/adapter/out/provider/DistributedProviderTest.java
```

No application source file changes package. The existing `port/in`, `port/out`,
`result`, and `service` packages remain intact. The empty `application/context`
and `adapter/out/observability` directories are removed from the filesystem.

## 2. Dependency and Reference Map

Apply these exact package replacements in Java package declarations and imports:

| Old package | New package |
|---|---|
| `com.incode.verification.domain.aggregate` | `com.incode.verification.domain.verification` |
| `com.incode.verification.domain.entity` | `com.incode.verification.domain.company` |
| `com.incode.verification.domain.policy` | `com.incode.verification.domain.provider` |
| `com.incode.verification.domain.type.ProviderFailure` | `com.incode.verification.domain.provider.ProviderFailure` |
| `com.incode.verification.domain.type.ProviderResult` | `com.incode.verification.domain.provider.ProviderResult` |
| `com.incode.verification.domain.type.ProviderType` | `com.incode.verification.domain.provider.ProviderType` |
| `com.incode.verification.domain.type.VerificationState` | `com.incode.verification.domain.verification.VerificationState` |
| `com.incode.verification.domain.type.VerificationStatus` | `com.incode.verification.domain.verification.VerificationStatus` |
| `com.incode.verification.domain.valueobject.InvalidQueryException` | `com.incode.verification.domain.query.InvalidQueryException` |
| `com.incode.verification.domain.valueobject.NormalizedQuery` | `com.incode.verification.domain.query.NormalizedQuery` |
| `com.incode.verification.domain.valueobject.UuidV7` | `com.incode.verification.domain.identity.UuidV7` |
| `com.incode.verification.adapter.config` for configuration classes and properties | `com.incode.verification.configuration` |
| `com.incode.verification.adapter.config.FreeProvider` | `com.incode.verification.adapter.out.provider.FreeProvider` |
| `com.incode.verification.adapter.config.PremiumProvider` | `com.incode.verification.adapter.out.provider.PremiumProvider` |
| `com.incode.verification.adapter.config.DistributedFreeProvider` | `com.incode.verification.adapter.out.provider.DistributedFreeProvider` |
| `com.incode.verification.adapter.config.DistributedPremiumProvider` | `com.incode.verification.adapter.out.provider.DistributedPremiumProvider` |
| `com.incode.verification.adapter.config.ResilientProvider` | `com.incode.verification.adapter.out.provider.ResilientProvider` |
| `com.incode.verification.adapter.config.ProviderRateLimitExceededException` | `com.incode.verification.adapter.out.provider.ProviderRateLimitExceededException` |
| `com.incode.verification.adapter.out.expiration` | `com.incode.verification.adapter.in.scheduling` |
| `com.incode.verification.adapter.config.DistributedProviderResilienceConfiguration` | `com.incode.verification.configuration.DistributedProviderResilienceConfiguration` |
| `com.incode.verification.adapter.config.ProviderResilienceConfiguration` | `com.incode.verification.configuration.ProviderResilienceConfiguration` |

When a file under `configuration` refers to a provider implementation, import
the new `adapter.out.provider` package explicitly. Do not apply the generic
`adapter.config` replacement to those six provider implementation classes.

## 3. Tasks

### Task 1: Add domain topology coverage and migrate domain packages

**Files:**

- Create: `company-check-service/src/test/java/com/incode/verification/architecture/DomainPackageStructureTest.java`
- Move: the 11 domain files listed in the Domain moves table
- Modify: Java imports and fully qualified references in `src/main/java` and `src/test/java` matching the domain replacement table
- Test: `company-check-service/src/test/java/com/incode/verification/domain/VerificationTest.java`

**Interfaces:**

- Consumes: existing domain classes and their current public APIs.
- Produces: concept packages `domain.company`, `domain.identity`,
  `domain.provider`, `domain.query`, and `domain.verification`.

- [ ] **Step 1: Write the failing structure test**

Create `DomainPackageStructureTest.java` with this exact content:

```java
package com.incode.verification.architecture;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;

class DomainPackageStructureTest {
  private static final Path DOMAIN_ROOT =
      Path.of("src/main/java/com/incode/verification/domain");

  @Test
  void groupsDomainClassesByBusinessConcept() {
    assertFilesExist(
        "company/Company.java",
        "identity/UuidV7.java",
        "provider/FallbackPolicy.java",
        "provider/ProviderFailure.java",
        "provider/ProviderResult.java",
        "provider/ProviderType.java",
        "query/InvalidQueryException.java",
        "query/NormalizedQuery.java",
        "verification/Verification.java",
        "verification/VerificationState.java",
        "verification/VerificationStatus.java");

    assertDirectoriesAbsent("aggregate", "entity", "policy", "type", "valueobject");
  }

  private void assertFilesExist(String... relativePaths) {
    for (String relativePath : relativePaths) {
      assertTrue(Files.exists(DOMAIN_ROOT.resolve(relativePath)), relativePath);
    }
  }

  private void assertDirectoriesAbsent(String... relativePaths) {
    for (String relativePath : relativePaths) {
      assertFalse(Files.exists(DOMAIN_ROOT.resolve(relativePath)), relativePath);
    }
  }
}
```

- [ ] **Step 2: Run the structure test and confirm red**

Run from `company-check-service`:

```bash
./gradlew test --tests com.incode.verification.architecture.DomainPackageStructureTest
```

Expected: the test task runs but `DomainPackageStructureTest` fails because
the concept directories do not exist yet.

- [ ] **Step 3: Move domain files and update package declarations**

Run from `company-check-service`:

```bash
mkdir -p src/main/java/com/incode/verification/domain/company
mkdir -p src/main/java/com/incode/verification/domain/identity
mkdir -p src/main/java/com/incode/verification/domain/provider
mkdir -p src/main/java/com/incode/verification/domain/query
mkdir -p src/main/java/com/incode/verification/domain/verification
git mv src/main/java/com/incode/verification/domain/aggregate/Verification.java src/main/java/com/incode/verification/domain/verification/Verification.java
git mv src/main/java/com/incode/verification/domain/entity/Company.java src/main/java/com/incode/verification/domain/company/Company.java
git mv src/main/java/com/incode/verification/domain/policy/FallbackPolicy.java src/main/java/com/incode/verification/domain/provider/FallbackPolicy.java
git mv src/main/java/com/incode/verification/domain/type/ProviderFailure.java src/main/java/com/incode/verification/domain/provider/ProviderFailure.java
git mv src/main/java/com/incode/verification/domain/type/ProviderResult.java src/main/java/com/incode/verification/domain/provider/ProviderResult.java
git mv src/main/java/com/incode/verification/domain/type/ProviderType.java src/main/java/com/incode/verification/domain/provider/ProviderType.java
git mv src/main/java/com/incode/verification/domain/type/VerificationState.java src/main/java/com/incode/verification/domain/verification/VerificationState.java
git mv src/main/java/com/incode/verification/domain/type/VerificationStatus.java src/main/java/com/incode/verification/domain/verification/VerificationStatus.java
git mv src/main/java/com/incode/verification/domain/valueobject/InvalidQueryException.java src/main/java/com/incode/verification/domain/query/InvalidQueryException.java
git mv src/main/java/com/incode/verification/domain/valueobject/NormalizedQuery.java src/main/java/com/incode/verification/domain/query/NormalizedQuery.java
git mv src/main/java/com/incode/verification/domain/valueobject/UuidV7.java src/main/java/com/incode/verification/domain/identity/UuidV7.java
rmdir src/main/java/com/incode/verification/domain/aggregate
rmdir src/main/java/com/incode/verification/domain/entity
rmdir src/main/java/com/incode/verification/domain/policy
rmdir src/main/java/com/incode/verification/domain/type
rmdir src/main/java/com/incode/verification/domain/valueobject
```

Use `apply_patch` to update the package declaration in each moved file and
replace every old domain import according to the replacement table. Update
the domain imports in application, adapter, and test sources. Architecture
test references are updated in Task 3.

- [ ] **Step 4: Run domain tests and confirm green**

```bash
./gradlew test --tests com.incode.verification.architecture.DomainPackageStructureTest --tests com.incode.verification.domain.VerificationTest
```

Expected: `DomainPackageStructureTest` and `VerificationTest` pass with zero
failures.

- [ ] **Step 5: Commit the domain migration**

```bash
git add -p
git diff --cached --name-status
git commit -m "refactor(domain): organize packages by business concept"
```

In the interactive staging step, stage the moved domain files, the new domain
structure test, and only import/package hunks caused by this migration. Do not
stage unrelated existing changes in application, adapter, or test files.

### Task 2: Separate configuration, provider adapters, and scheduling

**Files:**

- Create: `company-check-service/src/test/java/com/incode/verification/architecture/AdapterPackageStructureTest.java`
- Move: the six provider implementation files listed in Adapter and configuration moves
- Move: `src/main/java/com/incode/verification/adapter/out/expiration/VerificationExpirationScheduler.java`
- Move: the 15 configuration files listed in Adapter and configuration moves
- Move: `src/test/java/com/incode/verification/adapter/config/DistributedProviderTest.java`
- Modify: imports in configuration, application, adapter, and test sources

**Interfaces:**

- Consumes: `application.port.in`, `application.port.out`, and the concept-based domain packages from Task 1.
- Produces: `configuration`, `adapter.in.scheduling`, and provider classes in `adapter.out.provider`.

- [ ] **Step 1: Write the failing adapter structure test**

Create `AdapterPackageStructureTest.java` with this exact content:

```java
package com.incode.verification.architecture;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;

class AdapterPackageStructureTest {
  private static final Path SOURCE_ROOT = Path.of("src/main/java/com/incode/verification");

  @Test
  void separatesConfigurationInboundSchedulingAndProviderAdapters() {
    assertTrue(Files.exists(SOURCE_ROOT.resolve("configuration/ApplicationConfiguration.java")));
    assertTrue(Files.exists(SOURCE_ROOT.resolve("configuration/ProviderResilienceConfiguration.java")));
    assertTrue(
        Files.exists(
            SOURCE_ROOT.resolve(
                "adapter/in/scheduling/VerificationExpirationScheduler.java")));
    assertTrue(
        Files.exists(
            SOURCE_ROOT.resolve("adapter/out/provider/FreeProvider.java")));
    assertTrue(
        Files.exists(
            SOURCE_ROOT.resolve("adapter/out/provider/ResilientProvider.java")));

    assertFalse(Files.exists(SOURCE_ROOT.resolve("adapter/config")));
    assertFalse(Files.exists(SOURCE_ROOT.resolve("adapter/out/expiration")));
  }
}
```

- [ ] **Step 2: Run the adapter structure test and confirm red**

```bash
./gradlew test --tests com.incode.verification.architecture.AdapterPackageStructureTest
```

Expected: the test fails because configuration and provider files still live
under `adapter/config`, and the scheduler still lives under
`adapter/out/expiration`.

- [ ] **Step 3: Move configuration and provider files**

Run from `company-check-service`:

```bash
mkdir -p src/main/java/com/incode/verification/configuration
mkdir -p src/main/java/com/incode/verification/adapter/in/scheduling
git mv src/main/java/com/incode/verification/adapter/config/ApplicationConfiguration.java src/main/java/com/incode/verification/configuration/ApplicationConfiguration.java
git mv src/main/java/com/incode/verification/adapter/config/CacheConfiguration.java src/main/java/com/incode/verification/configuration/CacheConfiguration.java
git mv src/main/java/com/incode/verification/adapter/config/CoordinationConfiguration.java src/main/java/com/incode/verification/configuration/CoordinationConfiguration.java
git mv src/main/java/com/incode/verification/adapter/config/CoordinationProperties.java src/main/java/com/incode/verification/configuration/CoordinationProperties.java
git mv src/main/java/com/incode/verification/adapter/config/DatabaseProperties.java src/main/java/com/incode/verification/configuration/DatabaseProperties.java
git mv src/main/java/com/incode/verification/adapter/config/DatabaseRetryProperties.java src/main/java/com/incode/verification/configuration/DatabaseRetryProperties.java
git mv src/main/java/com/incode/verification/adapter/config/DistributedProviderResilienceConfiguration.java src/main/java/com/incode/verification/configuration/DistributedProviderResilienceConfiguration.java
git mv src/main/java/com/incode/verification/adapter/config/LocalCoordinationConfiguration.java src/main/java/com/incode/verification/configuration/LocalCoordinationConfiguration.java
git mv src/main/java/com/incode/verification/adapter/config/ObservabilityConfiguration.java src/main/java/com/incode/verification/configuration/ObservabilityConfiguration.java
git mv src/main/java/com/incode/verification/adapter/config/PersistenceConfiguration.java src/main/java/com/incode/verification/configuration/PersistenceConfiguration.java
git mv src/main/java/com/incode/verification/adapter/config/ProviderHttpConfiguration.java src/main/java/com/incode/verification/configuration/ProviderHttpConfiguration.java
git mv src/main/java/com/incode/verification/adapter/config/ProviderRateLimitProperties.java src/main/java/com/incode/verification/configuration/ProviderRateLimitProperties.java
git mv src/main/java/com/incode/verification/adapter/config/ProviderResilienceConfiguration.java src/main/java/com/incode/verification/configuration/ProviderResilienceConfiguration.java
git mv src/main/java/com/incode/verification/adapter/config/VerificationCacheExpiry.java src/main/java/com/incode/verification/configuration/VerificationCacheExpiry.java
git mv src/main/java/com/incode/verification/adapter/config/VerificationProperties.java src/main/java/com/incode/verification/configuration/VerificationProperties.java
git mv src/main/java/com/incode/verification/adapter/config/DistributedFreeProvider.java src/main/java/com/incode/verification/adapter/out/provider/DistributedFreeProvider.java
git mv src/main/java/com/incode/verification/adapter/config/DistributedPremiumProvider.java src/main/java/com/incode/verification/adapter/out/provider/DistributedPremiumProvider.java
git mv src/main/java/com/incode/verification/adapter/config/FreeProvider.java src/main/java/com/incode/verification/adapter/out/provider/FreeProvider.java
git mv src/main/java/com/incode/verification/adapter/config/PremiumProvider.java src/main/java/com/incode/verification/adapter/out/provider/PremiumProvider.java
git mv src/main/java/com/incode/verification/adapter/config/ProviderRateLimitExceededException.java src/main/java/com/incode/verification/adapter/out/provider/ProviderRateLimitExceededException.java
git mv src/main/java/com/incode/verification/adapter/config/ResilientProvider.java src/main/java/com/incode/verification/adapter/out/provider/ResilientProvider.java
git mv src/main/java/com/incode/verification/adapter/out/expiration/VerificationExpirationScheduler.java src/main/java/com/incode/verification/adapter/in/scheduling/VerificationExpirationScheduler.java
mkdir -p src/test/java/com/incode/verification/adapter/out/provider
git mv src/test/java/com/incode/verification/adapter/config/DistributedProviderTest.java src/test/java/com/incode/verification/adapter/out/provider/DistributedProviderTest.java
rmdir src/main/java/com/incode/verification/adapter/config
rmdir src/main/java/com/incode/verification/adapter/out/expiration
rmdir src/test/java/com/incode/verification/adapter/config
```

Use `apply_patch` to update package declarations. Apply the split replacement
rules exactly: configuration files use
`com.incode.verification.configuration`; provider implementations and
`DistributedProviderTest` use
`com.incode.verification.adapter.out.provider`; the scheduler uses
`com.incode.verification.adapter.in.scheduling`.

Update configuration imports for the moved provider implementations in
`DistributedProviderResilienceConfiguration.java` and
`ProviderResilienceConfiguration.java`. Update the moved test's package so it
can continue accessing package-private provider classes.

- [ ] **Step 4: Run adapter tests and confirm green**

```bash
./gradlew test --tests com.incode.verification.architecture.AdapterPackageStructureTest --tests com.incode.verification.adapter.out.provider.DistributedProviderTest --tests com.incode.verification.configuration.IncodeCompositionTest --tests com.incode.verification.configuration.RuntimeProfileConfigurationTest
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 5: Commit the adapter migration**

```bash
git add -p
git diff --cached --name-status
git commit -m "refactor(adapter): separate configuration and inbound scheduling"
```

In the interactive staging step, stage the moved configuration/provider/
scheduling files, the moved provider test, the new adapter structure test, and
only import/package hunks caused by this migration. Keep unrelated existing
changes out of the commit.

### Task 3: Update architecture checks and run the complete service gate

**Files:**

- Modify: `company-check-service/src/test/java/com/incode/verification/architecture/ModulithArchitectureTest.java`
- Modify: `company-check-service/src/test/java/com/incode/verification/architecture/HexagonalDependencyTest.java`
- Modify: any remaining Java files reported by the old-package searches below
- Delete: empty `company-check-service/src/main/java/com/incode/verification/application/context`
- Delete: empty `company-check-service/src/main/java/com/incode/verification/adapter/out/observability`

**Interfaces:**

- Consumes: the final package map from Tasks 1 and 2.
- Produces: zero old package references and a passing architecture/quality gate.

- [ ] **Step 1: Search for stale package references**

Run from `company-check-service`:

```bash
tgrep -F 'com.incode.verification.domain.aggregate' src/main/java src/test/java
tgrep -F 'com.incode.verification.domain.entity' src/main/java src/test/java
tgrep -F 'com.incode.verification.domain.policy' src/main/java src/test/java
tgrep -F 'com.incode.verification.domain.type' src/main/java src/test/java
tgrep -F 'com.incode.verification.domain.valueobject' src/main/java src/test/java
tgrep -F 'com.incode.verification.adapter.config' src/main/java src/test/java
tgrep -F 'com.incode.verification.adapter.out.expiration' src/main/java src/test/java
```

Expected: no output from any command. If a command reports a file, update it
with `apply_patch` using the replacement table before continuing.

- [ ] **Step 2: Update architecture tests**

In `ModulithArchitectureTest.java` and `HexagonalDependencyTest.java`, use
`com.incode.verification.domain.verification.Verification` for the framework-free
domain class reference. Preserve every assertion and test name.

- [ ] **Step 3: Remove empty directories and verify the final tree**

Run:

```bash
rmdir src/main/java/com/incode/verification/application/context
rmdir src/main/java/com/incode/verification/adapter/out/observability
find src/main/java/com/incode/verification -type d -print | sort
```

Expected: the output contains `domain/company`, `domain/identity`,
`domain/provider`, `domain/query`, `domain/verification`,
`adapter/in/scheduling`, `configuration`, and no old taxonomy/configuration
directories.

- [ ] **Step 4: Run focused architecture tests**

```bash
./gradlew test --tests com.incode.verification.architecture.DomainPackageStructureTest --tests com.incode.verification.architecture.AdapterPackageStructureTest --tests com.incode.verification.architecture.ModulithArchitectureTest --tests com.incode.verification.architecture.HexagonalDependencyTest
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 5: Run the service fast gate**

```bash
./gradlew fastCheck
```

Expected: formatting, static analysis, unit tests, and coverage checks pass.

- [ ] **Step 6: Review the diff and commit the verification updates**

```bash
git diff --check
git status --short
git diff --find-renames --stat
git add -p
git diff --cached --name-status
git commit -m "test(architecture): enforce verification package structure"
```

In the interactive staging step, stage only the architecture-test import
updates and the final structural test changes. The staged diff must contain
only package moves, package/import updates, structure tests, and removal of
empty directories. It must not contain changes to behavior, APIs, schemas,
configuration keys, or unrelated worktree files.

## 4. Definition of Done

- [ ] Domain classes use `company`, `identity`, `provider`, `query`, and `verification` packages.
- [ ] No `aggregate`, `entity`, `policy`, `type`, or `valueobject` domain packages remain.
- [ ] Spring configuration and properties live in `configuration`.
- [ ] Provider implementations live in `adapter/out/provider`.
- [ ] The expiration scheduler lives in `adapter/in/scheduling`.
- [ ] Application `port/in`, `port/out`, `result`, and `service` boundaries remain unchanged.
- [ ] No old package references remain in service main or test sources.
- [ ] Architecture tests pass.
- [ ] `./gradlew fastCheck` passes.
- [ ] Service migration commits contain no unrelated existing changes.
