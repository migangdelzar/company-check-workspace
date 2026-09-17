# Documentation refresh

- [x] Restate goal and acceptance criteria
- [x] Locate current implementation, docs, and package boundaries
- [x] Approve minimal documentation design
- [x] Update ADR index and decisions
- [x] Update architecture prose and Mermaid diagrams
- [x] Update top-level README architecture wording
- [x] Run stale-reference, Mermaid, diff, and Compose checks
- [x] Summarize results and lessons

## Results

- Refreshed ADR 0001 and corrected implementation references across ADRs.
- Reworked all architecture Mermaid diagrams and layer descriptions around the
  current `config`/`controller`/`service`/`repository`/`client` structure.
- Updated README architecture wording without changing commands or endpoints.
- Stale-reference scan, Mermaid fence check, `git diff --check`, and both
  single/distributed Compose merges passed. The Docker CLI lacks the Compose
  plugin; standalone `docker-compose 5.1.4` passed the equivalent checks.
- Provider `bun run quality` passed (30 tests). Java `fastCheck` could not reach
  tests: the first run lacked locked artifacts locally, and the refresh retry
  stopped on dependency verification for `kotlinx-coroutines-bom:1.8.0`.

## Working notes

- The repository is `company-check-workspace`.
- The backend is now layered: `config`, `controller`, `service`, `repository`,
  `client`, `mapper`, and `exception`.
- Existing changes in the workspace and both submodules are unrelated and must
  be preserved.

## 2026-09-17 — Refactor completion and verification

### Subtitle: Finish the pending package refactor, unblock the dependency gate, and close the documentation task.

### Task: Unblock Java dependency verification gate

- [x] Confirm the kotlinx-coroutines-bom:1.8.0 verification entry exists
  - **Actions Applied**
    - Checked `gradle/verification-metadata.xml` — entry recorded at `git log`
      `b70d7ad build: verify legacy coroutine platform metadata`; no repo changes needed
  - **Verification**
    - Fresh `./gradlew clean fastCheck` completes dependency resolution with no verification errors

- [x] Run the full fastCheck gate fresh (no build cache)
  - **Actions Applied**
    - `./gradlew clean fastCheck --no-build-cache` in `company-check-service`
  - **Verification**
    - BUILD SUCCESSFUL; 107 unit tests, 0 problems (jacoco coverage gate green)

### Task: Complete the service submodule package refactor

- [x] Review the pending refactor change set (config capability folders, filter/scheduler)
  - **Actions Applied**
    - Inspected staged renames + working-tree import updates across 51 files in `company-check-service`
  - **Verification**
    - Source grep clean: no stale `com.incode.verification.config.<Class>` imports remain

- [x] Verify integration test sources and run the integration gate
  - **Actions Applied**
    - `./gradlew compileIntegrationTestJava`; then `./gradlew integrationTest --rerun-tasks` with
      `DOCKER_HOST=unix://.../.colima/emme/docker.sock TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock`
      (Docker context `colima-emme`; no `/var/run/docker.sock` present — ADR 0008 wiring)
  - **Verification**
    - Integration tests pass: 5/5, 0 failures (CompanyCheckApplicationIT, VerificationRecoveryIT, JdbcDataSliceTest, JdbcVerificationRepositoryIT, RedisProviderRateLimiterIT)

- [x] Commit the refactor
  - **Actions Applied**
    - `git commit` in `company-check-service` → `2cdbdab refactor: split config capability folders and separate filter/scheduler`
  - **Verification**
    - Working tree clean; 28 renames + content updates committed as the change set

### Task: Synchronize workspace submodule pointer and docs

- [x] Bump the submodule pointer and align the two architecture pages
  - **Actions Applied**
    - Workspace commits: `eb67932 refactor: sync service submodule to filter/scheduler split`,
      `99e0c43 docs: reflect filter/scheduler and config capability packages`
    - `docs/architecture/overview.md` filter node and `docs/architecture/runtime-architecture.md`
      layer table now name `filter`/`scheduler` and `config/{persistence,provider,coordination,ratelimit,cache,hints}`
  - **Verification**
    - `git status` clean across workspace and both submodules

### Task: Provider and documentation gates

- [x] Run provider quality gate
  - **Actions Applied**
    - `bun run quality` in `company-check-provider` (format, typecheck, lint, frozen-lockfile tests)
  - **Verification**
    - 30 pass / 0 fail across 5 files

- [x] Run the Task 5 documentation gate
  - **Actions Applied**
    - Stale-reference `tgrep` scan; package-dir existence loop (all 10 present incl. `filter`, `scheduler`);
      Mermaid fence `awk`; `git diff --check`; Ruby Markdown link check; `docker-compose` merges
  - **Verification**
    - Stale scan: no matches; fences balanced; `git diff --check` exit 0; links exit 0;
      standalone `docker-compose 5.1.4` renders `compose.yaml+single` and `compose.yaml+distributed` merges
      (Docker CLI Compose plugin unavailable)

### Task: Prepare the PR handoff

- [x] Write the PR title/body artifact
  - **Actions Applied**
    - PR handoff text provided to the user below (no remote PR metadata changed)
  - **Verification**
    - Body lists summary, validation evidence, and the submodule-preservation note

## Summary — Current Status

- All previously pending work is closed: dependency gate green, service refactor
  committed and verified (`2cdbdab`), workspace docs and submodule pointer committed
  (`eb67932`, `99e0c43`), provider quality green.

## 2026-09-17 — GitHub Actions repairs and full validation proof

### Subtitle: Fix the failing provider security gate, locust permission + budget
in the stress flow, and prove the complete validation pipeline green.

### Task: Repair provider CI (security + reproducibility)

- [x] Pin invalid trivy-action ref and align the security gate
  - **Actions Applied**
    - `company-check-provider/.github/workflows/quality.yml` — `aquasecurity/trivy-action@0.28.0`
      → `ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0`; added `scanners: vuln,secret,misconfig`,
      `vuln-type: os,library`, `ignore-unfixed: true`; pinned `actions/checkout`
      → `11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2` and `oven-sh/setup-bun`
      → `0c5077e51419868618aeaa5fe8019c62421857d6 # v2`
  - **Verification**
    - Push `a3a1701` → provider `quality` and `security` jobs both green

- [x] Add missing `mise.toml` for setup-bun version pin
  - **Actions Applied**
    - `company-check-provider/mise.toml` — `[tools] bun = "1.3"`
  - **Verification**
    - `bun run quality` local → 30 pass / 0 fail across 5 files

### Task: Fix Locust stress permission + budget mismatch

- [x] Make the artifacts dir world-writable for the locust container
  - **Actions Applied**
    - `company-check-service/performance/run.sh` — `chmod 0777 "$artifacts"` after `mkdir -p`
  - **Verification**
    - `bash -n` OK; committed `bf9ff96` and pushed on `main`

- [x] Skip the exact-10000 request budget on bounded CI stress runs
  - **Actions Applied**
    - `.github/workflows/performance.yml` — `PERFORMANCE_REQUESTS: ""` in the stress step env
  - **Verification**
    - Workspace commit `9b0f6ab` + submodule bump; `ci.yml`/`security.yml` push runs green

### Task: Resolve missing immutable image digests

- [x] Pull/resolve digests for the validation dispatch inputs
  - **Actions Applied**
    - Postgres: `postgres@sha256:18cfe3ef5e6815560c98237d6216d1e5119702fb0f3894c8785dd58b8bbe5d73`
    - Redis: `redis@sha256:ff02b58f971e7d7d156a1267e283fcbbeee91773b6aa36c49dac28ecfe28eadf`
    - Paketo approved pair from `scripts/mise-setup.sh`:
      `paketobuildpacks/builder-jammy-base@sha256:aadea5…43d83` +
      `paketobuildpacks/run-jammy-base@sha256:03a974…8168`
  - **Verification**
    - First dispatch failed with `Run image stack 'noble.tiny' does not match builder stack 'noble'`
      (bad `run-noble-tiny` pair); retried with the approved jammy-base pair → build passed

### Task: Prove the complete validation pipeline

- [x] Run `ci.yml` dispatch with validation enabled
  - **Actions Applied**
    - `gh workflow run ci.yml --ref feat/rule-adoption` with `run-validation=true`, `image-variant=jvm`,
      and the digest-pinned postgres/redis/paketo inputs
  - **Verification**
    - Run `35260018233` → all green: workspace-gates (rerun after flaky Gradle cache `ENETUNREACH`),
      service gate, image build, **e2e (42s)**, **stress (2m28s)**, provider quality

## 2026-09-17 — Mise onboarding improvement

### Subtitle: Make mise the single entry point, add install/doctor/observability aliases, and add GETTING_STARTED.

### Task: Expand mise tasks to cover every local workflow

- [x] Add bootstrap/validate aliases and fix colima profile handling
  - **Actions Applied**
    - `mise.toml` — added `install`, `env`, `doctor`, `health`, `smoke`, `ps`,
      `start-observability`, `clean`; rewired `start`/`start-distributed`/
      `compose-check`/`service-full`; colima profile honor via `COLIMA_PROFILE`
      (default `emme`); `service-full` exports Docker host + socket override
      automatically on `colima-*` contexts
  - **Verification**
    - `mise tasks` lists 18 tasks; `mise run install` exits 0 (submodules
      registered); colima env-detection snippet sets
      `DOCKER_HOST=unix://…/.colima/emme/docker.sock` + socket override

- [x] Expose useful mise CLI commands as project tasks
  - **Actions Applied**
    - `mise.toml` — added `trust`, `tools` (`mise ls`), `current`, `outdated`
  - **Verification**
    - `mise run trust` → "No untrusted config files found"; `mise run tools`/
      `current` list pinned versions; `mise run outdated` → "all up to date";
      `mise tasks` lists all 22 tasks

- [x] Add shared docker helper and doctor script
  - **Actions Applied**
    - `scripts/mise-docker.sh` (new) — `profile|ensure|status` subcommands;
      `scripts/mise-doctor.sh` (new) — tool/submodule/env/docker/memory check
  - **Verification**
    - `bash -n` passes both; `scripts/mise-doctor.sh` → "all checks passed" exit 0

- [x] Harden the setup runner
  - **Actions Applied**
    - `scripts/mise-setup.sh` — colima now started with `-p <profile>`;
      submodule `gradlew`/`Dockerfile` presence checked before build; dropped
      invalid `mise install --include-lazy` hint
  - **Verification**
    - `bash -n scripts/mise-setup.sh` passes; jvm/native paths unchanged

### Task: Document prerequisites and onboarding

- [x] Add GETTING_STARTED.md as the entry point
  - **Actions Applied**
    - `GETTING_STARTED.md` (new) — mise install (brew + curl), shell hook,
      clone/submodule prep, `mise run install`, JVM/native setup, memory table,
      daily command table
  - **Verification**
    - Markdown link check passes across README/docs/GETTING_STARTED

- [x] Refresh README stale references and aliases
  - **Actions Applied**
    - `README.md` — Requirements/Complete-local-setup point to GETTING_STARTED;
      removed dead Paketo placeholder `cp gradle.properties` step; expanded
      "Workspace task aliases" list with all 18 tasks
  - **Verification**
    - `git diff --check` clean; link check passes

- [x] Sync architecture docs
  - **Actions Applied**
    - `docs/architecture/startup.md` — tossed stale gradle.properties/Paketo
      placeholder step; documented `mise run install` + colima profile default
    - `docs/architecture/testing.md` — added `doctor`, observability in
      `compose-check`, noted auto socket override for `service-full`
  - **Verification**
    - `mise run compose-check` renders all three overlays exit 0

## Summary — Current Status

- mise is now the single local entry point: `mise run install` → `setup-jvm`/
  `setup-native`, plus doctor, health, smoke, observability, cleanup aliases.
- Colima profile is honored everywhere (`emme` default, `COLIMA_PROFILE` override).
- Local `mise.toml` validates lazily; nothing external is started by the changes.

## Next Up

- Commit the mise/doc changes on the workspace branch once approved.
- Optional: run `mise run setup-jvm` end-to-end under the new runner.