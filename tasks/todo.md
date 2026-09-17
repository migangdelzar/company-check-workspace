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
