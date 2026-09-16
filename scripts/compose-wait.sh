#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
compose=(scripts/compose-command.sh)
timeout_seconds="${COMPOSE_WAIT_TIMEOUT_SECONDS:-120}"
deadline=$((SECONDS + timeout_seconds))
while (( SECONDS < deadline )); do
  status="$("${compose[@]}" ps --all --format '{{.Service}} {{.State}} {{.Health}}')"
  case "$status" in
    *" exited "*|*" dead "*) printf '%s\n' "$status" >&2; exit 1 ;;
  esac
  [[ "$status" == *"backend running healthy"* ]] && exit 0
done
printf 'compose services did not become healthy before timeout\n' >&2
"${compose[@]}" ps --all
exit 1
