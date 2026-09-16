#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$workspace_root"

service_commit="51a87333c11df15f8f6c0f10e9ebb5bef5f09a83"
provider_commit="ba38a652a51f1057b733c84f6d6464d6558d5902"

fail() { printf 'workspace validation failed: %s\n' "$1" >&2; exit 1; }

git config -f .gitmodules --get submodule.company-check-service.path >/dev/null || fail "service submodule missing"
git config -f .gitmodules --get submodule.company-check-provider.path >/dev/null || fail "provider submodule missing"

service_actual="$(git -C company-check-service rev-parse HEAD)"
provider_actual="$(git -C company-check-provider rev-parse HEAD)"
[ "$service_actual" = "$service_commit" ] || fail "service commit is not pinned"
[ "$provider_actual" = "$provider_commit" ] || fail "provider commit is not pinned"

git ls-files --error-unmatch company-check-service >/dev/null 2>&1 || fail "service is not tracked as a gitlink"
git ls-files --error-unmatch company-check-provider >/dev/null 2>&1 || fail "provider is not tracked as a gitlink"

for forbidden in .env .env.local company-check-service/.env company-check-provider/.env; do
  [ ! -e "$forbidden" ] || fail "forbidden file present: $forbidden"
done

printf 'workspace contract is valid\n'
