#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$workspace_root"

: "${COMPANY_CHECK_SERVICE_IMAGE:?set COMPANY_CHECK_SERVICE_IMAGE to an immutable image}"
: "${COMPANY_CHECK_PROVIDER_IMAGE:?set COMPANY_CHECK_PROVIDER_IMAGE to an immutable image}"
: "${POSTGRES_IMAGE:?set POSTGRES_IMAGE to an immutable image}"
: "${REDIS_IMAGE:?set REDIS_IMAGE to an immutable image}"

case "$COMPANY_CHECK_SERVICE_IMAGE $COMPANY_CHECK_PROVIDER_IMAGE $POSTGRES_IMAGE $REDIS_IMAGE" in
  *:latest*|*replace-with-approved-digest*)
    printf '%s\n' 'E2E requires approved immutable image references' >&2
    exit 2
    ;;
esac

compose_args=(docker compose)
api_url="http://127.0.0.1:${COMPANY_CHECK_SERVICE_PORT:-8080}"
artifacts="${COMPOSE_E2E_ARTIFACTS_DIR:-$workspace_root/.e2e-artifacts}"

cleanup() {
  status=$?
  if (( status != 0 )); then
    mkdir -p "$artifacts"
    "${compose_args[@]}" logs --no-color >"$artifacts/compose.log" 2>&1 || true
    "${compose_args[@]}" ps --all >"$artifacts/compose-ps.txt" 2>&1 || true
  fi
  "${compose_args[@]}" down >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup EXIT INT TERM

"${compose_args[@]}" up -d
"$workspace_root/scripts/compose-wait.sh"

if command -v bats >/dev/null 2>&1; then
  BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-30}" \
    COMPANY_CHECK_API_URL="$api_url" \
    bats e2e/verification.bats e2e/provider-failures.bats
else
  printf '%s\n' 'bats is required to run Compose E2E scenarios' >&2
  exit 127
fi
