# Company Check Workspace

This repository is the parent workspace contract for the Company Check service
and provider repositories. The two projects remain independent Git submodules;
the parent records only their pinned commits and workspace-level configuration.

## Layout

- `company-check-service/` — service submodule
- `company-check-provider/` — provider submodule
- `mise.toml` — pinned workspace revisions and task entry point
- `.env.example` — safe local defaults
- `workspace-validate.sh` — source-level contract checks

## Compose lifecycle

Set approved image digests in .env, then use scripts/compose-up.sh followed by
scripts/compose-wait.sh. Stop the stack with scripts/compose-down.sh; it does
not remove volumes. Image values are inputs because this parent does not own
the service/provider source repositories.

Observability is opt-in: run `docker compose --profile observability up -d`
after setting its image and retention values in `.env`. Grafana is exposed on
`GRAFANA_PORT`; local storage is bounded to 24 hours. The static smoke check is
`scripts/observability-smoke.sh`.

The service submodule pointer is intentionally not changed by workspace
configuration work. To update it, checkout an approved service commit inside
the service repository, then commit only the parent gitlink as described in
the update flow below. The same hook applies to the provider submodule.

## Update flow

Update a submodule in its own repository, commit and push that repository, then
update the parent pointer:

```sh
git -C company-check-service fetch
git -C company-check-service checkout <approved-commit>
git add company-check-service
git commit -m "build: update service submodule"
```

Repeat for `company-check-provider` as needed. Do not commit service or provider
files into this parent repository; only their submodule pointers belong here.

Copy `.env.example` to `.env` for local values. Keep real credentials out of
Git and out of shared examples.

## Contract check

`workspace-validate.sh` is the workspace contract check. Run it explicitly when
validation is desired:

```sh
./workspace-validate.sh
```
