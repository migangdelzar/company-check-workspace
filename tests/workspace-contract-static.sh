#!/usr/bin/env bash
set -euo pipefail

validator="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/workspace-validate.sh"

grep -Eq 'for client in e2e/verification\.bats e2e/provider-failures\.bats; do' "$validator"
grep -Eq 'for client in e2e/verification\.bats e2e/provider-failures\.bats performance/locustfile\.py; do' "$validator"
grep -Eq 'canonical field missing from E2E client' "$validator"
grep -Eq 'self\\.client\\.post' "$validator"
! grep -Eq 'canonical field missing from executable clients' "$validator"

printf 'workspace contract static assertions are present\n'
