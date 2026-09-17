#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
gradlew="$repo_root/company-check-service/gradlew"

[[ -f "$gradlew" ]] || {
  echo "company-check-service submodule is not initialized; run 'mise run install'" >&2
  exit 1
}
[[ $# -gt 0 ]] || {
  echo "Usage: scripts/mise-gradle.sh <gradle-task> [args...]" >&2
  exit 2
}

context="$(docker context show 2>/dev/null || true)"
case "$context" in
  colima-*)
    export DOCKER_HOST="$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}')"
    export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
    ;;
esac

exec "$gradlew" -p "$repo_root/company-check-service" "$@"