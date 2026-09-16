#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
deadline=$((SECONDS + \${COMPOSE_WAIT_TIMEOUT_SECONDS:-120}))
while (( SECONDS < deadline )); do
  status="$(docker compose ps --all --format '{{.Service}} {{.State}} {{.Health}}')"
  case "$status" in
    *" exited "*|*" dead "*) printf '%s\n' "$status" >&2; exit 1 ;;
  esac
  [[ "$status" == *"backend running healthy"* ]] && exit 0
done
printf 'compose services did not become healthy before timeout\n' >&2
docker compose ps --all
exit 1
