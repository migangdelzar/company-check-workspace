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

## Next Up

- Push `company-check-service` (`main`) and workspace (`feat/rule-adoption`),
  and open the PR using the handoff title/body (needs user confirmation).