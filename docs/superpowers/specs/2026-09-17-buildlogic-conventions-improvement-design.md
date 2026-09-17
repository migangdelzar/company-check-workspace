# Build-Logic and Convention Plugin Improvement

## Scope

Refine the service's Gradle build-logic so the shared convention plugins, the
build-logic plugin build, the version catalog, and the service build script are
consistent, DRY, and idiomatic — without changing behavior. Task names, gate
composition (`fastCheck` -> `qualityGate`), ports, and the public Gradle API
surface stay identical.

Scope is limited to the `company-check-service` Gradle build. The provider
submodule (Bun/Fastify) is untouched.

## Design

Apply a set of small, behavior-preserving improvements to the existing four
convention plugins, `build-logic/build.gradle.kts`, `gradle/libs.versions.toml`,
and the root `build.gradle.kts`.

### 1. DRY the duplicated gate list in `com.incode.quality-conventions.gradle.kts`

The `unitCheck` task (lines ~116-128) and the `check` task (lines ~130-140) both
declare the same six-task dependency list:

```kotlin
"spotlessCheck", "checkstyleMain", "checkstyleTest", "checkstyleTestFixtures",
"test", "jacocoTestReport", "jacocoTestCoverageVerification"
```

Extract one shared property and reference it from both tasks so the quality gate
composition is a single source of truth.

### 2. Catalog hygiene in `gradle/libs.versions.toml` and `build.gradle.kts`

- Move the inline `checkstyle("org.codehaus.plexus:plexus-utils:3.6.1")` in
  `build.gradle.kts` into the version catalog: add a `plexus-utils` version and
  a `plexus-utils` library alias, then reference `libs.plexus.utils` from the
  `checkstyle` configuration.
- Drop the explicit `version.ref = "spring-boot"` from the
  `spring-boot-starter-aspectj` alias. The artifact is BOM-managed (verified in
  the resolved `spring-boot-dependencies-4.1.1.pom`), so pinning by the Spring
  Boot version is redundant and inconsistent with every other starter alias in
  the catalog.

### 3. Replace `ProcessBuilder` with `ExecOperations` in
   `com.incode.container-conventions.gradle.kts`

The `docker(arguments: List<String>): String` helper builds a raw
`ProcessBuilder`, starts it, reads `errorStream`, and blocks on `waitFor()`.
Replace it with the project-provided `ExecOperations`/`ExecSpec` API, capturing
standard and error output into a `ByteArrayOutputStream` and throwing on a
non-zero exit code. Keep the returned string's contract (trimmed stdout+stderr)
so the two call sites (`imageSmoke`'s docker calls) require no other edits.

Preserve `imageSmoke`'s `notCompatibleWithConfigurationCache(...)` declaration:
the existing TestKit test `containerCheckDryRunHandlesItsConfigurationCacheBoundary`
asserts the dry-run still works under the configuration cache, and it must stay
green.

### 4. Explicit compose directory in `composeDigestCheck`

`composeDigestCheck` resolves the overlay files with
`rootProject.layout.projectDirectory.dir("../$it")`, silently relying on the
service repo sitting one directory beneath the workspace root. Use an explicit
`val workspaceDir = rootProject.layout.projectDirectory.dir("..")` (or an
equivalent `rootProject.file("..")` provider) and map each compose filename
against it. This documents the relative-boundary intent instead of hiding it.

### 5. De-magic the suite loop in `com.incode.testing-conventions.gradle.kts`

The `testSuiteNames.forEach` loop special-cases `integrationTest` with an `if`
branch to add `testcontainers-*` dependencies. Replace the branch with a
`Map<String, List<String>>` mapping suite name -> extra implementation catalog
aliases (or a per-suite `extraSuiteDependencies(suiteName)` provider), so the
dependencies are data rather than a stringly-typed conditional.

### 6. Use generated catalog accessors in `build-logic/build.gradle.kts`

`build-logic/settings.gradle.kts` already installs the `libs` catalog with
`versionCatalogs { create("libs") { from(files("../gradle/libs.versions.toml")) } }`.
Replace the manual `libsCatalog`/`VersionCatalogsExtension` lookup with the
generated `libs` accessors (backtick-quoting any hyphenated aliases) for the
plugin dependency declarations, matching how the plugins block already uses
`alias(libs.plugins.*)`.

### 7. Pull the Detekt JVM target into the catalog

`build-logic/build.gradle.kts` hardcodes `jvmTarget = "22"` inside the Detekt
configuration. Move `22` into `[versions]` (e.g. `detekt-jvm-target = "22"`)
and reference it, keeping the existing explanatory comment about why the target
is pinned to 22.

## Out of Scope

- New task names, gate rewiring, or changes to `fastCheck`/`qualityGate`.
- Spring/application code, ports, DTOs, or contracts.
- The provider submodule build.
- Changing the shape of the four convention plugins (no merge into one plugin).

## Verification

- `./gradlew -p company-check-service buildLogicCheck` passes.
- The existing TestKit suite (`build-logic/src/test/.../CapabilityTaskFunctionalTest.kt`)
  passes unchanged — this is the behavioral gate for the whole refactor.
- `./gradlew -p company-check-service fastCheck` passes.
- `git diff --check` clean; spotless/ktlint formatting applied.