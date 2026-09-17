# Documentation refresh

- [x] Restate goal and acceptance criteria
- [x] Locate current implementation, docs, and package boundaries
- [x] Approve minimal documentation design
- [ ] Update ADR index and decisions
- [ ] Update architecture prose and Mermaid diagrams
- [ ] Update top-level README architecture wording
- [ ] Run stale-reference, Mermaid, diff, and Compose checks
- [ ] Summarize results and lessons

## Working notes

- The repository is `company-check-workspace`.
- The backend is now layered: `config`, `controller`, `service`, `repository`,
  `client`, `mapper`, and `exception`.
- Existing changes in the workspace and both submodules are unrelated and must
  be preserved.
