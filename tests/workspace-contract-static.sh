#!/usr/bin/env bash
set -euo pipefail

validator="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/workspace-validate.sh"

grep -Eq 'for client in e2e/verification\.bats e2e/provider-failures\.bats; do' "$validator"
grep -Eq 'for client in e2e/verification\.bats e2e/provider-failures\.bats performance/locustfile\.py; do' "$validator"
grep -Eq 'canonical field missing from E2E client' "$validator"
grep -Eq 'self\\.client\\.post' "$validator"
! grep -Eq 'canonical field missing from executable clients' "$validator"

get_forms='curl -X GET /backend-service
curl --get /backend-service'
post_forms='curl -X POST /backend-service
curl --request POST /backend-service'
grep -Eq -- '-X\[\[:space:\]\]\+GET.*backend-service|backend-service.*-X\[\[:space:\]\]\+GET' "$validator"
grep -Eq -- '-X\[\[:space:\]\]\+POST.*backend-service|backend-service.*-X\[\[:space:\]\]\+POST' "$validator"
! printf '%s\n' "$get_forms" | grep -Eq -- '--request[[:space:]]+POST|-[Xx][[:space:]]+POST'
printf '%s\n' "$post_forms" | grep -Eq -- '--request[[:space:]]+POST|-[Xx][[:space:]]+POST'

printf 'workspace contract static assertions are present\n'
