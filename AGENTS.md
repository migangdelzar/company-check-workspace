# Workspace guidance

- Keep `company-check-service` and `company-check-provider` independent Git submodules; parent changes must not edit their files.
- Preserve the backend contract: submit with `POST /backend-service?verificationId=<uuid>&query=<text>` and retrieve with `GET /verifications/<verificationId>`.
- Use canonical response fields `cin`, `name`, `registrationDate`, `address`, and `isActive`; lifecycle statuses are `IN_PROGRESS`, `COMPLETED`, and `FAILED`.
- Keep the Compose-only, single-backend, single-node topology. Do not add Kubernetes, replicas, or a service mesh.
- All image references must be immutable digest-pinned values (`@sha256:<digest>`).
- Do not use fixed sleeps in workspace scripts or clients; use bounded health polling.
- Run `./workspace-validate.sh` after workspace contract changes.
