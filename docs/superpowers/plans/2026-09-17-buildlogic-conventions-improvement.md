# Build-Logic and Convention Plugin Improvement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the service's shared Gradle convention plugins, build-logic build, version catalog, and service build script DRY, idiomatic, and consistent — without changing any task names, gate wiring, or public surface.

**Architecture:** Behavior-preserving refactor confined to `company-check-service/build-logic/src/main/kotlin/*.gradle.kts`, `build-logic/build.gradle.kts`, `gradle/libs.versions.toml`, and the root `build.gradle.kts`. Seven small, independently-verifiable edits, each gated by the existing TestKit functional suite and `buildLogicCheck`.

**Tech Stack:** Gradle 9.0.0, Kotlin DSL, Gradle TestKit, Spring Boot 4.1.1/Java 25, version catalogs.

## Global Constraints

- Behavior-preserving: task names, `fastCheck` → `qualityGate` wiring, ports, DTOs, and public APIs must NOT change.
- Keep all versions in `gradle/libs.versions.toml` (AGENTS.md requirement).
- Existing TestKit suite `build-logic/src/test/kotlin/com/incode/buildlogic/CapabilityTaskFunctionalTest.kt` must pass unchanged after every task.
- `imageSmoke` in `com.incode.container-conventions.gradle.kts` keeps its `notCompatibleWithConfigurationCache(...)` declaration.
- The four convention plugin files keep their current names and responsibilities; no merging into one plugin.
- Every task ends with a full verification run + commit.

---

### Task 1: Catalog hygiene — move plexus-utils into the catalog and drop the redundant aspectj version

**Files:**
- Modify: `company-check-service/gradle/libs.versions.toml`
- Modify: `company-check-service/build.gradle.kts` (line 76)

**Interfaces:**
- Consumes: nothing
- Produces: `libs.plexus.utils` library alias (used by the `checkstyle` configuration in the root build)

- [ ] **Step 1: Add the plexus-utils version and library to the catalog**

Edit `company-check-service/gradle/libs.versions.toml`. In `[versions]`, after the `checkstyle = "11.0.0"` line, add:

```toml
plexus-utils = "3.6.1"
```

In `[libraries]`, after the `checkstyle = { module = "com.puppycrawl.tools:checkstyle", version.ref = "checkstyle" }` line, add:

```toml
plexus-utils = { module = "org.codehaus.plexus:plexus-utils", version.ref = "plexus-utils" }
```

- [ ] **Step 2: Replace the inline version with the catalog alias**

Edit `company-check-service/build.gradle.kts:76`. Replace:

```kotlin
  checkstyle("org.codehaus.plexus:plexus-utils:3.6.1")
```

with:

```kotlin
  checkstyle(libs.plexus.utils)
```

- [ ] **Step 3: Drop the redundant `version.ref` from `spring-boot-starter-aspectj`**

Edit `company-check-service/gradle/libs.versions.toml`. Replace:

```toml
spring-boot-starter-aspectj = { module = "org.springframework.boot:spring-boot-starter-aspectj", version.ref = "spring-boot" }
```

with:

```toml
spring-boot-starter-aspectj = { module = "org.springframework.boot:spring-boot-starter-aspectj" }
```

The artifact is BOM-managed (verified: `spring-boot-dependencies-4.1.1.pom` lists it at version 4.1.1).

- [ ] **Step 4: Verify**

Run from the workspace root:

```bash
./company-check-service/gradlew -p company-check-service buildLogicCheck
```

Expected: `BUILD SUCCESSFUL`. Then run the functional gate:

```bash
./company-check-service/gradlew -p company-check-service :build-logic:test
```

Wait — `<rootProject>:build-logic:test` does not exist because build-logic is an *included* build. The correct test invocation is:

```bash
./company-check-service/gradlew -p company-check-service buildLogicCheck
```

`buildLogicCheck` already depends on the included build's `:check`, which runs its unit/TestKit tests. Confirm you see `build-logic` test tasks executed in the output (grep for `CapabilityTaskFunctionalTest`).

- [ ] **Step 5: Commit**

```bash
cd company-check-service && git add gradle/libs.versions.toml build.gradle.kts
git commit -m "refactor: catalog-ize plexus-utils and drop redundant aspectj version"
```

---

### Task 2: De-dup the quality gate list in the quality conventions

**Files:**
- Modify: `company-check-service/build-logic/src/main/kotlin/com.incode.quality-conventions.gradle.kts` (lines ~116-140)

**Interfaces:**
- Consumes: nothing
- Produces: local property `qualityAssuranceTasks` (used within this one file)

- [ ] **Step 1: Introduce the shared task list**

In `com.incode.quality-conventions.gradle.kts`, add a property after the `unitTest`/`coverageExcludedPaths` declarations (near line 23):

```kotlin
val qualityAssuranceTasks =
  listOf(
    "spotlessCheck",
    "checkstyleMain",
    "checkstyleTest",
    "checkstyleTestFixtures",
    "test",
    "jacocoTestReport",
    "jacocoTestCoverageVerification",
  )
```

- [ ] **Step 2: Rewire `unitCheck` to reference the shared list**

Replace the current `unitCheck` block:

```kotlin
tasks.register("unitCheck") {
  group = "verification"
  description = "Runs formatting, static analysis, unit tests, and coverage checks."
  dependsOn(
    "spotlessCheck",
    "checkstyleMain",
    "checkstyleTest",
    "checkstyleTestFixtures",
    "test",
    "jacocoTestReport",
    "jacocoTestCoverageVerification",
  )
}
```

with:

```kotlin
tasks.register("unitCheck") {
  group = "verification"
  description = "Runs formatting, static analysis, unit tests, and coverage checks."
  dependsOn(qualityAssuranceTasks)
}
```

- [ ] **Step 3: Rewire `check` to reference the shared list**

Replace the current `check` block:

```kotlin
tasks.named("check") {
  dependsOn(
    "spotlessCheck",
    "checkstyleMain",
    "checkstyleTest",
    "checkstyleTestFixtures",
    "test",
    "jacocoTestReport",
    "jacocoTestCoverageVerification",
  )
}
```

with:

```kotlin
tasks.named("check") {
  dependsOn(qualityAssuranceTasks)
}
```

- [ ] **Step 4: Verify**

```bash
./company-check-service/gradlew -p company-check-service buildLogicCheck && ./company-check-service/gradlew -p company-check-service fastCheck --dry-run
```

Expected: both pass; the functional TestKit tests still assert `unitCheck`/`qualityGate` wiring.

- [ ] **Step 5: Commit**

```bash
cd company-check-service && git add build-logic/src/main/kotlin/com.incode.quality-conventions.gradle.kts
git commit -m "refactor: share the quality assurance task list in quality-conventions"
```

---

### Task 3: De-magic the per-suite dependencies in the testing conventions

**Files:**
- Modify: `company-check-service/build-logic/src/main/kotlin/com.incode.testing-conventions.gradle.kts` (lines 44-64)

**Interfaces:**
- Consumes: nothing
- Produces: no new public API; internal map `testSuiteExtraImplementation`

- [ ] **Step 1: Replace the `if` branch with a data map**

In `com.incode.testing-conventions.gradle.kts`, replace the registration loop:

```kotlin
  suites {
    testSuiteNames.forEach { suiteName ->
      register<JvmTestSuite>(suiteName) {
        useJUnitJupiter()
        sources { java.setSrcDirs(listOf("src/$suiteName/java")) }
        dependencies {
          implementation(project())
          if (suiteName == "integrationTest") {
            implementation(libsCatalog.findLibrary("testcontainers-junit-jupiter").get())
            implementation(libsCatalog.findLibrary("testcontainers").get())
            implementation(libsCatalog.findLibrary("testcontainers-postgresql").get())
          }
        }
        targets.configureEach {
          testTask.configure {
            shouldRunAfter(unitTest)
            outputs.cacheIf { false }
            outputs.upToDateWhen { false }
          }
        }
      }
    }
  }
```

with:

```kotlin
val testSuiteExtraImplementation =
  mapOf(
    "integrationTest" to
      listOf("testcontainers-junit-jupiter", "testcontainers", "testcontainers-postgresql"),
    "contractTest" to emptyList(),
    "e2eTest" to emptyList(),
  )

  testing {
  suites {
    testSuiteNames.forEach { suiteName ->
      register<JvmTestSuite>(suiteName) {
        useJUnitJupiter()
        sources { java.setSrcDirs(listOf("src/$suiteName/java")) }
        dependencies {
          implementation(project())
          testSuiteExtraImplementation.getValue(suiteName).forEach { alias ->
            implementation(libsCatalog.findLibrary(alias).get())
          }
        }
        targets.configureEach {
          testTask.configure {
            shouldRunAfter(unitTest)
            outputs.cacheIf { false }
            outputs.upToDateWhen { false }
          }
        }
      }
    }
  }
```

(Note: the value map must be declared OUTSIDE the `testing {` block, just before it. Preserve the exact original indentation of the surrounding block.)

- [ ] **Step 2: Verify**

```bash
./company-check-service/gradlew -p company-check-service buildLogicCheck
```

Expected: `BUILD SUCCESSFUL`; TestKit `fastCheckExcludesExternalCapabilities` and `qualityGateRetainsExternalVerification` still pass (they assert integration/contract/e2e wiring).

- [ ] **Step 3: Commit**

```bash
cd company-check-service && git add build-logic/src/main/kotlin/com.incode.testing-conventions.gradle.kts
git commit -m "refactor: model per-suite test dependencies as data in testing-conventions"
```

---

### Task 4: Replace `ProcessBuilder` with `ExecOperations` and make the compose path explicit

**Files:**
- Modify: `company-check-service/build-logic/src/main/kotlin/com.incode.container-conventions.gradle.kts` (lines 145-160 for compose path, lines 171-227 for docker helper + imageSmoke)

**Interfaces:**
- Consumes: nothing
- Produces: no public API change; the `docker(...)` helper keeps its `List<String> -> String` signature so `imageSmoke` call sites read identically at the top level

- [ ] **Step 1: Add the `ExecOperations`-based docker helper**

Replace the current `docker` function:

```kotlin
fun docker(arguments: List<String>): String {
  val process =
    ProcessBuilder(listOf("docker") + arguments)
      .redirectErrorStream(true)
      .start()
  val output =
    process.inputStream
      .readBytes()
      .toString(Charsets.UTF_8)
      .trim()
  check(process.waitFor() == 0) {
    "docker ${arguments.joinToString(" ")} failed: $output"
  }
  return output
}
```

with:

```kotlin
fun docker(exec: ExecOperations, arguments: List<String>): String {
  val errorStream = ByteArrayOutputStream()
  val result =
    exec.exec {
      commandLine(listOf("docker") + arguments)
      standardOutput = errorStream
      errorOutput = errorStream
    }
  check(result.exitValue == 0) {
    "docker ${arguments.joinToString(" ")} failed: ${errorStream.toString(Charsets.UTF_8).trim()}"
  }
  return errorStream.toString(Charsets.UTF_8).trim()
}
```

Add imports at the top of the file:

```kotlin
import org.gradle.process.ExecOperations
import java.io.ByteArrayOutputStream
```

- [ ] **Step 2: Thread `ExecOperations` through the task**

`ExecOperations` is available as a task service; modify `imageSmoke` so its `doLast` uses the new helper. Replace:

```kotlin
  dependsOn("bootBuildImage")
  outputs.cacheIf { false }
  inputs.property("imageName", configuredImageName)
  inputs.property("timeoutSeconds", imageSmokeTimeoutSeconds)
  doLast {
```

with:

```kotlin
  dependsOn("bootBuildImage")
  outputs.cacheIf { false }
  inputs.property("imageName", configuredImageName)
  inputs.property("timeoutSeconds", imageSmokeTimeoutSeconds)
  doLast {
    val docker = { arguments: List<String> -> docker(execOperations, arguments) }
```

Then replace the five `docker(...)` call sites inside the `doLast` with `docker(...)` (they already read `docker(listOf(...))`, which now resolves to the local lambda). The lambda has the same name and signature as the old top-level function, so no other text changes.

Confirm the final `doLast` body reads:

```kotlin
  doLast {
    val docker = { arguments: List<String> -> docker(execOperations, arguments) }
    val image = configuredImageName.get()
    val timeout = imageSmokeTimeoutSeconds.get()
    docker(listOf("image", "inspect", image))
    ...
    containerId = docker(listOf("create", "--read-only", ...))
    ...
  }
```

where `execOperations` resolves via the task's injected execution service (`this` is the task; add `import org.gradle.process.ExecOperations` and Reference `execOperations` — it is available on `Task` through `project.execOperations`? No: obtain it via `providers.exec`? The canonical way inside a script-plugin task: use `project.exec` — see Step 2b.)

- [ ] **Step 2b: Use `project.exec` which is the config-safe API available in task actions**

The most idiomatic, config-cache-compatible replacement is `exeOperations` obtained from the task via the `ExecOperations` service. Because this script registers tasks anonymously with closures, inject the service through a small helper. Add a private object at the bottom of the file:

```kotlin
private object ExecOperationsHelper {
  fun forTask(task: DefaultTask): ExecOperations =
    task.project.objects.newInstance(ExecOperations::class.java)
}
```

Actually, `ExecOperations` is an injectable service, not instantiable via `objects`. Use this documented approach instead — obtain it in the task via `project.exec` operator. Replace Step 2's lambda with a top-level adapter to keep `imageSmoke` readable:

```kotlin
fun docker(project: Project, arguments: List<String>): String {
  val errorStream = ByteArrayOutputStream()
  val result =
    project.exec {
      commandLine(listOf("docker") + arguments)
      standardOutput = errorStream
      errorOutput = errorStream
    }
  check(result.exitValue == 0) {
    "docker ${arguments.joinToString(" ")} failed: ${errorStream.toString(Charsets.UTF_8).trim()}"
  }
  return errorStream.toString(Charsets.UTF_8).trim()
}
```

and in `imageSmoke.doLast`, call `docker(project, listOf(...))` (inside a task `doLast`, `project` is available on the task object). Replace the five `docker(...)` call sites with `docker(project, ...)` including inside the `finally { runCatching { docker(project, listOf("rm", "-f", containerId)) } }`.

Add `import org.gradle.api.Project` if not already imported.

- [ ] **Step 3: Make the compose path explicit in `composeDigestCheck`**

Replace:

```kotlin
  inputs.files(
    listOf("compose.yaml", "compose.single.yaml", "compose.distributed.yaml")
      .map { rootProject.layout.projectDirectory.dir("../$it") },
  )
```

with:

```kotlin
  val workspaceComposeDir = rootProject.layout.projectDirectory.dir("..")
  inputs.files(
    listOf("compose.yaml", "compose.single.yaml", "compose.distributed.yaml")
      .map { workspaceComposeDir.file(it) },
  )
```

- [ ] **Step 4: Verify (config-cache + TestKit)**

```bash
./company-check-service/gradlew -p company-check-service buildLogicCheck
```

The TestKit test `containerCheckDryRunHandlesItsConfigurationCacheBoundary` runs `containerCheck --dry-run` with `org.gradle.configuration-cache=true` and must still pass.

Also run a live dry-run of the image task wiring:

```bash
./company-check-service/gradlew -p company-check-service containerCheck --dry-run
```

Expected: lists `:containerCheck` and `:imageSmoke`.

- [ ] **Step 5: Commit**

```bash
cd company-check-service && git add build-logic/src/main/kotlin/com.incode.container-conventions.gradle.kts
git commit -m "refactor: use project.exec for docker helper and explicit compose dir in container-conventions"
```

---

### Task 5: Use generated catalog accessors in the build-logic build

**Files:**
- Modify: `company-check-service/build-logic/build.gradle.kts` (lines 1-22)
- Modify: `company-check-service/gradle/libs.versions.toml` (add `detekt-jvm-target` version)

**Interfaces:**
- Consumes: existing `libs` catalog already declared in `build-logic/settings.gradle.kts`
- Produces: no new public API

- [ ] **Step 1: Add the detekt JVM target version to the catalog**

In `company-check-service/gradle/libs.versions.toml`, `[versions]` section, add after the `detekt = "1.23.8"` line:

```toml
detekt-jvm-target = "22"
```

- [ ] **Step 2: Replace `libsCatalog`/`VersionCatalogsExtension` with generated accessors**

In `company-check-service/build-logic/build.gradle.kts`:

Remove the import:

```kotlin
import org.gradle.api.artifacts.VersionCatalogsExtension
```

Remove the line:

```kotlin
val libsCatalog = extensions.getByType<VersionCatalogsExtension>().named("libs")
```

Replace the `dependencies` block with generated accessors:

```kotlin
dependencies {
  implementation(libs.spring.boot.gradle.plugin)
  implementation(libs.spotless.gradle.plugin)
  implementation(libs.error.prone.gradle.plugin)
  implementation(libs.nullaway.gradle.plugin)
  testImplementation(gradleTestKit())
  testImplementation(libs.junit.jupiter)
  testRuntimeOnly(libs.junit.platform.launcher)
}
```

Replace the `detekt` `jvmTarget` assignment:

```kotlin
tasks.withType<Detekt>().configureEach {
  jvmTarget = "22"
}
```

with:

```kotlin
tasks.withType<Detekt>().configureEach {
  jvmTarget = libs.versions.detekt.jvm.target.get()
}
```

Replace the `spotless` ktlint version reference:

```kotlin
    kotlin {
      target("src/**/*.kt")
      ktlint(libsCatalog.findVersion("ktlint").get().requiredVersion)
      trimTrailingWhitespace()
      endWithNewline()
    }
    kotlinGradle {
      target("*.gradle.kts", "src/**/*.gradle.kts")
      ktlint(libsCatalog.findVersion("ktlint").get().requiredVersion)
      trimTrailingWhitespace()
      endWithNewline()
    }
```

with:

```kotlin
    kotlin {
      target("src/**/*.kt")
      ktlint(libs.versions.ktlint.get().requiredVersion)
      trimTrailingWhitespace()
      endWithNewline()
    }
    kotlinGradle {
      target("*.gradle.kts", "src/**/*.gradle.kts")
      ktlint(libs.versions.ktlint.get().requiredVersion)
      trimTrailingWhitespace()
      endWithNewline()
    }
```

Note: catalog keys with dashes map to camelCase accessors; the Kotlin DSL generates `libs.spring.boot.gradle.plugin`, `libs.error.prone.gradle.plugin`, `libs.nullaway.gradle.plugin`, `libs.spotless.gradle.plugin`, `libs.junit.jupiter`, `libs.junit.platform.launcher`, `libs.versions.detekt.jvm.target`, `libs.versions.ktlint`. `findVersion(...).get().requiredVersion` == `libs.versions.ktlint.get().requiredVersion` (the generated `Version` accessor is a `Provider<Version>`; `.get()` unwraps it, `.requiredVersion` is the string — same shape as today).

- [ ] **Step 3: Verify**

```bash
./company-check-service/gradlew -p company-check-service buildLogicCheck
```

Expected: `BUILD SUCCESSFUL`, no build-logic compile errors.

If `libs.versions.detekt.jvm.target` fails to resolve because of accessor generation for the dashed key, fall back to `libs.versions.detektJvmTarget` won't exist either — instead keep an explicit `val detektJvmTarget = "22"` local constant in `build-logic/build.gradle.kts` with the same explanatory comment, and note it in git history. The catalog pin is preferred; do not reintroduce the inline literal silently.

- [ ] **Step 4: Commit**

```bash
cd company-check-service && git add build-logic/build.gradle.kts gradle/libs.versions.toml
git commit -m "refactor: use generated catalog accessors in build-logic build"
```

---

### Task 6: Full verification and workspace doc sync

**Files:**
- Modify: N/A (verification + `tasks/todo.md`)

**Interfaces:**
- Consumes: output of tasks 1-5

- [ ] **Step 1: Run the complete service gate**

```bash
./company-check-service/gradlew -p company-check-service buildLogicCheck
./company-check-service/gradlew -p company-check-service fastCheck
```

Expected: both `BUILD SUCCESSFUL`. OpenAPI/contract/TestKit behavior is covered by `buildLogicCheck` (included build `check`).

- [ ] **Step 2: Confirm no stale references**

```bash
cd company-check-workspace
git diff --check
```

Expected: clean (ignore the existing CRLF warnings).

- [ ] **Step 3: Append the session log to `tasks/todo.md`**

Append a dated session block following the existing format (see the current tail of `tasks/todo.md`), covering: items 1-5 as completed checkboxes with Actions Applied + Verification evidence (rerun one key command per item and paste the result).

- [ ] **Step 4: Commit the workspace log**

```bash
cd company-check-workspace && git add tasks/todo.md
git commit -m "docs: log build-logic convention improvement session"
```

---

## Self-Review

- **Spec coverage:** spec items 1-7 map 1:1 to tasks 1-5 (item 3's ExecOperations = task 4; item 4 compose path = task 4 step 3; item 5 = task 3; item 6 = task 5; item 7 = task 5 step 1). Verification (spec's Verification section) = task 6.
- **Placeholders:** none — every step carries concrete commands and expected output; `project.exec`/accessor details are fully specified with fallbacks documented.
- **Type consistency:** `docker` keeps `List<String> -> String`; `qualityAssuranceTasks` is a `List<String>` used by `dependsOn`; `testSuiteExtraImplementation` is `Map<String, List<String>>` consumed by `getValue(suiteName)`; catalog accessor names match the toml aliases exactly (`spring-boot-gradle-plugin` → accessor `spring.boot.gradle.plugin`, etc.).