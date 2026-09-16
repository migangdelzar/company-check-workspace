#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$workspace_root"

service_commit="308c0cf"
provider_commit="e5e08dd"

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

grep -Eq '^  backend:$' compose.yaml || fail "core backend service missing"
! grep -Eq 'replicas:|mesh|swarm' compose.yaml || fail "deprecated replica or mesh topology present"
grep -Eq '^    profiles: \[debug\]$' compose.yaml || fail "debug profile missing"
grep -Eq '^    profiles: \[observability\]$' compose.yaml || fail "observability profile missing"
grep -Eq '^    profiles: \[performance\]$' compose.yaml || fail "performance profile missing"
grep -Eq 'timeout_seconds=.*COMPOSE_WAIT_TIMEOUT_SECONDS' scripts/compose-wait.sh || fail "bounded compose polling missing"
! grep -R -Eq '(^|[[:space:];])sleep[[:space:]]+[0-9]+' --exclude-dir=.git --exclude='*.lock' . || fail "fixed sleep found in workspace"

for image in COMPANY_CHECK_SERVICE_IMAGE COMPANY_CHECK_PROVIDER_IMAGE POSTGRES_IMAGE REDIS_IMAGE PROMETHEUS_IMAGE MIMIR_IMAGE LOKI_IMAGE TEMPO_IMAGE GRAFANA_IMAGE LOCUST_IMAGE; do
  grep -Eq "^${image}=.*@sha256:" .env.example || fail "${image} is not digest-only in .env.example"
done

printf 'workspace contract is valid\n'
