# Mise-Based JVM and Native Image Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mise run setup-jvm` and `mise run setup-native` complete, memory-aware local onboarding commands for the JVM and native image paths.

**Architecture:** Keep Gradle/Paketo as the only service image implementation. Put shared validation, provider build, service image build, Compose startup, and health waiting in `scripts/mise-setup.sh`; expose explicit JVM/native wrappers through `mise.toml`. Update current onboarding docs to prefer those wrappers while retaining manual Gradle commands as advanced fallback.

**Tech Stack:** mise, Bash, Bun, Docker, standalone Docker Compose, Gradle Kotlin DSL, Spring Boot Paketo image build, Markdown.

## Global Constraints

- Make `mise` the primary local onboarding interface for service validation, provider checks, image builds, Compose startup, and shutdown.
- `mise run setup-jvm` builds the provider image, builds the JVM service image, starts the single-node Compose stack, and waits for backend health.
- `mise run setup-native` performs the same flow with `-PimageVariant=native -PnativeOptimization=b`.
- Both tasks use `company-check-provider:local` and `company-check-service:local`.
- Create `.env` from `.env.example` only when `.env` is absent; never overwrite an existing environment file.
- Require real digest-pinned Paketo builder/run references in `company-check-service/gradle.properties`; never invent digest values.
- JVM image build recommendation: 4 GiB Docker memory; 2 GiB is a constrained lower-bound attempt.
- Native image build recommendation: 12 GiB Docker memory.
- Do not stop or reconfigure Docker Desktop or an already-running Colima VM automatically.
- Replace stale `docker-cli-plugin-docker-compose` references with the pinned `docker-compose` executable.
- Preserve existing API, persistence, provider, Compose, observability, and image contracts.
- Preserve the existing dirty `compose.yaml` and `company-check-service` submodule changes.

---

### Task 1: Add the shared mise setup runner

**Files:**
- Create: `scripts/mise-setup.sh`

**Interfaces:**
- Consumes: one positional argument, exactly `jvm` or `native`; `.env.example`; `company-check-service/gradle.properties`; the existing provider Dockerfile; Gradle `image` task; and single-node Compose overlays.
- Produces: local provider/service images tagged `:local`, a healthy single-node Compose stack, or a precise failure before any destructive runtime change.

- [ ] **Step 1: Create the executable Bash runner with strict variant parsing.**

  The script must begin with `#!/usr/bin/env bash` and `set -euo pipefail`. Resolve the repository root from the script location, select `memory_gib=4` for `jvm` and `memory_gib=12` for `native`, and reject all other arguments with usage text.

- [ ] **Step 2: Validate tools and local configuration without overwriting files.**

  Require `bun`, `docker`, `docker-compose`, and `curl` on `PATH`. If `.env` is absent, copy `.env.example` to `.env`; if it exists, leave it unchanged. Require `company-check-service/gradle.properties` and validate both `paketoBuilderImage` and `paketoRunImage` against `^[^@[:space:]]+@sha256:[0-9A-Fa-f]{64}$`; reject missing values and `<64-hex-digest>` placeholders with an actionable message.

- [ ] **Step 3: Add Docker runtime and memory checks.**

  If `docker info` fails and `colima` exists, run `colima start --cpu 4 --memory "$memory_gib"`; then require `docker info` to succeed. Read `docker info --format '{{.MemTotal}}'`. If it returns a numeric byte count below `memory_gib * 1024^3`, fail with the detected value and the exact recommendation to increase Docker/Colima memory. Do not stop, resize, or recreate an already-running runtime.

- [ ] **Step 4: Build the provider and service images through existing project paths.**

  Build the Gradle argument array first, then append the native-only flag:

  ```sh
  (cd "$repo_root/company-check-provider" && bun install --frozen-lockfile && bun run quality)
  docker build -t company-check-provider:local "$repo_root/company-check-provider"
  gradle_args=(
    -p "$repo_root/company-check-service"
    image
    "-PimageVariant=$variant"
    -PimageName=company-check-service:local
    --no-daemon
    --no-parallel
    --max-workers=1
    --console=plain
  )
  if [[ "$variant" == native ]]; then
    gradle_args+=(-PnativeOptimization=b)
  fi
  "$repo_root/company-check-service/gradlew" "${gradle_args[@]}"
  ```

  Implement the conditional native argument in Bash using an array so JVM mode never receives native-only flags.

- [ ] **Step 5: Render, start, and health-check single-node Compose.**

  Render with `docker-compose -f compose.yaml -f compose.single.yaml config`, start with `up -d --scale backend=1`, then poll `http://localhost:8080/actuator/health` for up to 120 seconds. On timeout, print `docker-compose ps --all` and recent backend/provider/PostgreSQL logs before failing. Print the final image tags and health URL on success.

- [ ] **Step 6: Validate the runner locally without building images.**

  Run:

  ```sh
  bash -n scripts/mise-setup.sh
  scripts/mise-setup.sh invalid
  ```

  Expected: syntax check passes; invalid mode exits non-zero and prints usage. Do not run a real image build until the mise wrappers exist.

- [ ] **Step 7: Commit the runner.**

  ```sh
  chmod +x scripts/mise-setup.sh
  git add scripts/mise-setup.sh
  git commit -m "build: add mise image setup runner"
  ```

### Task 2: Simplify and correct mise task aliases

**Files:**
- Modify: `mise.toml`

**Interfaces:**
- Consumes: `scripts/mise-setup.sh` from Task 1 and existing task names used by README/CI.
- Produces: explicit `setup-jvm`/`setup-native` tasks plus working validation, provider, Compose, and lifecycle aliases.

- [ ] **Step 1: Add complete setup tasks.**

  Add:

  ```toml
  [tasks.setup-jvm]
  description = "Build JVM images and start the single-node stack"
  run = "scripts/mise-setup.sh jvm"

  [tasks.setup-native]
  description = "Build native images and start the single-node stack"
  run = "scripts/mise-setup.sh native"
  ```

- [ ] **Step 2: Fix service/provider aliases.**

  Use `./company-check-service/gradlew -p company-check-service fastCheck` for `validate`, `./company-check-service/gradlew -p company-check-service qualityGate` for `service-full`, and `cd company-check-provider && bun install --frozen-lockfile && bun run quality` for `provider`.

- [ ] **Step 3: Replace stale Compose executable names.**

  Use `docker-compose` for `start`, `start-distributed`, `stop`, and `logs`. Keep the existing overlay files and scale values. Make `stop` bring down both single-node and distributed project overlays with `--remove-orphans`.

- [ ] **Step 4: Add a Compose validation alias.**

  Add `compose-check` that renders both single-node and distributed configurations with `docker-compose ... config >/dev/null`.

- [ ] **Step 5: Run task-definition checks.**

  Run:

  ```sh
  mise tasks
  mise run validate -- --dry-run
  mise run provider -- --dry-run
  bash -n scripts/mise-setup.sh
  ```

  Expected: `setup-jvm`, `setup-native`, `compose-check`, and existing aliases are listed; the shell runner passes syntax validation. If the installed mise version does not support `--dry-run` for task aliases, use `mise run --help` and inspect the rendered task list instead of changing task semantics.

- [ ] **Step 6: Commit mise configuration.**

  ```sh
  git add mise.toml
  git commit -m "build: simplify local workflows with mise"
  ```

### Task 3: Update onboarding and image documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/architecture/startup.md`
- Modify: `docs/architecture/testing.md`
- Modify: `company-check-service/docs/image-contract.md`

**Interfaces:**
- Consumes: the Task 1 runner, Task 2 aliases, current Gradle image contract, and the official Paketo native-image reference links in the approved design.
- Produces: one recommended JVM command, one recommended native command, accurate memory guidance, and manual fallback commands for advanced users.

- [ ] **Step 1: Make README recommend mise-first onboarding.**

  Add a short “Complete local setup” section with:

  ```sh
  mise trust
  mise install --include-lazy
  cp company-check-service/gradle.properties.example company-check-service/gradle.properties
  # replace both Paketo placeholders with approved @sha256:<64-hex> references
  mise run setup-jvm
  # or: mise run setup-native
  ```

  State that JVM builds should have 4 GiB Docker memory and native builds 12 GiB; explain that the setup task checks the active daemon and does not overwrite Docker/Colima settings. Move direct Gradle image commands under an “Advanced/manual image build” subsection.

- [ ] **Step 2: Update startup documentation.**

  Make `mise run setup-jvm` and `mise run setup-native` the primary flow after digest configuration. Keep direct Compose and Gradle commands as troubleshooting/advanced fallback. Document `.env` creation behavior, health waiting, single-node startup, and native/JVM memory recommendations.

- [ ] **Step 3: Update testing/performance aliases.**

  Add `mise run validate`, `mise run service-full`, `mise run provider`, `mise run compose-check`, and `mise run performance` to the command reference. Clarify that the setup tasks build images and start the stack; they do not replace `qualityGate` or the performance runner.

- [ ] **Step 4: Update the service image contract.**

  Add the two `mise` setup commands and the memory table while preserving the immutable Paketo digest, native optimization, publishing, and `imageSmoke` rules. Link to the official Paketo Java Native Image Buildpack reference and state that the repository memory values are operational recommendations, not hard minimums.

- [ ] **Step 5: Run documentation checks.**

  Run:

  ```sh
  ruby -e 'require "pathname"; bad=[]; Dir["docs/**/*.md", "README.md", "company-check-service/docs/*.md"].each { |file| text=File.read(file); text.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each { |link| next if link.start_with?("http://", "https://", "#", "mailto:"); target=link.split("#", 2).first; next if target.empty?; path=Pathname.new(file).dirname.join(target); bad << "#{file}: #{link}" unless path.exist? } }; abort bad.join("\n") unless bad.empty?'
  rg --no-index -n -e 'setup-jvm|setup-native|4 GiB|12 GiB|paketoBuilderImage|paketoRunImage' README.md docs company-check-service/docs/image-contract.md
  git diff --check
  ```

  Expected: link check exits 0, both setup commands and memory values appear, and no whitespace errors are reported.

- [ ] **Step 6: Commit documentation.**

  ```sh
  git add README.md docs/architecture/startup.md docs/architecture/testing.md company-check-service/docs/image-contract.md
  git commit -m "docs: document mise image onboarding"
  ```

### Task 4: Run the complete verification gate and prepare the PR handoff

**Files:**
- Review: `mise.toml`
- Review: `scripts/mise-setup.sh`
- Review: `README.md`, `docs/`, and `company-check-service/docs/image-contract.md`

**Interfaces:**
- Consumes: all changes from Tasks 1–3 and any existing uncommitted Compose/submodule state.
- Produces: verification evidence and a ready-to-paste PR description.

- [ ] **Step 1: Verify scripts and task definitions.**

  Run:

  ```sh
  bash -n scripts/mise-setup.sh
  mise tasks
  mise run compose-check
  ```

  Expected: syntax passes, both setup aliases are listed, and both Compose merges render.

- [ ] **Step 2: Run fast project checks through mise.**

  Run:

  ```sh
  mise run validate
  mise run provider
  ```

  Expected: service fast check and provider quality pass, or report the exact external/dependency blocker.

- [ ] **Step 3: Exercise setup error paths.**

  Run the setup runner with an invalid variant and inspect the missing/placeholder digest and low-memory branches using temporary copies or controlled shell inputs; do not alter the user’s real `gradle.properties`, `.env`, Docker Desktop settings, or Colima VM.

- [ ] **Step 4: Run real image setup when prerequisites permit.**

  Run `mise run setup-jvm` with approved Paketo digests and at least 4 GiB Docker memory. Run `mise run setup-native` only when the active daemon has at least 12 GiB available. If those prerequisites are unavailable, report that exact limitation rather than weakening validation.

- [ ] **Step 5: Verify scope and preserve unrelated changes.**

  ```sh
  git diff --check
  git status --short
  git diff --submodule=short -- company-check-service
  git diff --name-only HEAD~3..HEAD
  ```

  Expected: new committed changes are limited to the runner, `mise.toml`, and the documented Markdown files; existing `compose.yaml` and service-submodule changes remain untouched.

- [ ] **Step 6: Prepare the PR handoff.**

  Use title `build: simplify onboarding with mise JVM/native setup` and include:

  ```markdown
  ## Summary
  - Added complete `mise run setup-jvm` and `mise run setup-native` onboarding commands.
  - Added Docker memory checks and documented 4 GiB JVM / 12 GiB native recommendations.
  - Updated validation, provider, Compose, startup, and image-contract guidance to prefer mise.

  ## Validation
  - `bash -n scripts/mise-setup.sh`
  - `mise run compose-check`
  - `mise run validate`
  - `mise run provider`
  - JVM/native setup results or exact prerequisite limitations

  ## Notes
  - Paketo builder/run references remain digest-pinned and are never invented by setup.
  - Existing unrelated Compose and service-submodule changes were preserved.
  ```
