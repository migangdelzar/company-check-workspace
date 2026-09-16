#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$workspace_root"

fail() { printf 'workspace validation failed: %s\n' "$1" >&2; exit 1; }

client_contract_root=""
if [ "${1:-}" = "--client-contract-root" ]; then
  [ "$#" -eq 2 ] || fail "--client-contract-root requires a directory"
  client_contract_root="$2"
  [ -d "$client_contract_root" ] || fail "client contract root is not a directory"
fi
client_root="${client_contract_root:-$workspace_root}"

service_commit="b77903ca453525bb2410fd59ee17be6183020291"
provider_commit="eee653d028753459a839b386ca8a96daff476469"

if [ -z "$client_contract_root" ]; then
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

for client in e2e/verification.bats e2e/provider-failures.bats performance/locustfile.py; do
  [ -f "$client_root/$client" ] || fail "executable client missing: $client"
  ! grep -Eq 'NO_MATCH|(^|[^A-Z_])MATCH([^A-Z_]|$)' "$client_root/$client" || fail "stale match status in $client"
  ! grep -Eq 'companyIdentificationNumber|companyName' "$client_root/$client" || fail "legacy company field in $client"
done

for client in e2e/verification.bats e2e/provider-failures.bats; do
  ! grep -Eq -- '--get[[:space:]].*backend-service|/backend-service.*--get|-X[[:space:]]+GET.*backend-service|backend-service.*-X[[:space:]]+GET' "$client_root/$client" || fail "stale GET backend endpoint in $client"
  grep -Eq -- '--request[[:space:]]+POST.*backend-service|backend-service.*--request[[:space:]]+POST|-X[[:space:]]+POST.*backend-service|backend-service.*-X[[:space:]]+POST' "$client_root/$client" || fail "POST backend endpoint missing in $client"
  grep -Eq -- 'verificationId=' "$client_root/$client" || fail "verificationId query parameter missing in $client"
  grep -Eq -- 'query=' "$client_root/$client" || fail "query parameter missing in $client"
done

grep -Eq 'self\.client\.post\([[:space:]]*"/backend-service"' "$client_root/performance/locustfile.py" || fail "Locust POST backend endpoint missing"
grep -Eq 'params=.*verificationId.*query|params=.*query.*verificationId' "$client_root/performance/locustfile.py" || fail "Locust backend query parameters missing"
! grep -Eq 'self\.client\.get\([[:space:]]*"/backend-service"' "$client_root/performance/locustfile.py" || fail "stale Locust GET backend endpoint"

for field in cin name registrationDate address isActive; do
  grep -Eq "(^|[^[:alnum:]_])${field}([^[:alnum:]_]|$)" "$client_root/e2e/verification.bats" || fail "canonical field missing from E2E client: $field"
done
grep -Eq 'IN_PROGRESS|COMPLETED|FAILED' "$client_root/e2e/verification.bats" || fail "canonical lifecycle statuses missing from E2E client"
else
  :
fi

printf 'workspace contract is valid\n'
