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
