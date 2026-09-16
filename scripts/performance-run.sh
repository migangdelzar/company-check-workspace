#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$workspace_root"
: "${COMPANY_CHECK_SERVICE_IMAGE:?set COMPANY_CHECK_SERVICE_IMAGE to an immutable image}"
: "${COMPANY_CHECK_PROVIDER_IMAGE:?set COMPANY_CHECK_PROVIDER_IMAGE to an immutable image}"
: "${POSTGRES_IMAGE:?set POSTGRES_IMAGE to an immutable image}"
: "${REDIS_IMAGE:?set REDIS_IMAGE to an immutable image}"
: "${LOCUST_IMAGE:?set LOCUST_IMAGE to a pinned immutable image}"

artifacts="${PERFORMANCE_ARTIFACTS_DIR:-$workspace_root/.performance-artifacts}"
compose=("$workspace_root/scripts/compose-command.sh")
mkdir -p "$artifacts"
set -a
. "${PERFORMANCE_SCENARIOS_FILE:-$workspace_root/performance/scenarios.env}"
set +a

status=0
cleanup() {
  status=$?
  "${compose[@]}" --profile performance logs --no-color >"$artifacts/compose.log" 2>&1 || true
  "${compose[@]}" --profile performance ps --all >"$artifacts/compose-ps.txt" 2>&1 || true
  "${compose[@]}" --profile performance down >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup EXIT INT TERM

"${compose[@]}" --profile performance up -d
"$workspace_root/scripts/compose-wait.sh"
"${compose[@]}" --profile performance run --rm locust \
  --headless --users "$PERFORMANCE_USERS" --spawn-rate "$PERFORMANCE_SPAWN_RATE" \
  --run-time "$PERFORMANCE_DURATION" --only-summary \
  --html /mnt/artifacts/report.html --csv /mnt/artifacts/locust

awk -F, -v max_p95="$PERFORMANCE_P95_MS" -v max_failures="$PERFORMANCE_FAILURE_PERCENT" '
  NR == 1 { for (i = 1; i <= NF; i++) { if ($i == "95%") p95 = i; if ($i == "Failure %") failures = i } next }
  $1 != "Aggregated" && $(p95) > max_p95 { print "p95 threshold exceeded: " $1 > "/dev/stderr"; bad = 1 }
  $1 != "Aggregated" && $(failures) > max_failures { print "failure threshold exceeded: " $1 > "/dev/stderr"; bad = 1 }
  END { exit bad }
' "$artifacts/locust_stats.csv"
