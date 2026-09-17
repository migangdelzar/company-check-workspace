#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/mise-docker.sh <profile|ensure|status> [memory-gib]" >&2
  exit 2
}

colima_profile() {
  if [[ -n "${COLIMA_PROFILE:-}" ]]; then
    printf '%s\n' "$COLIMA_PROFILE"
    return
  fi
  printf '%s\n' "emme"
}

ensure() {
  local memory_gib="${1:-4}"
  if docker info >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v colima >/dev/null 2>&1; then
    echo "Docker is unavailable and colima is not installed; run 'mise run install' first" >&2
    return 1
  fi
  local profile
  profile="$(colima_profile)"
  echo "Docker is unavailable; starting Colima profile '$profile' with ${memory_gib} GiB" >&2
  colima start -p "$profile" --cpu 4 --memory "$memory_gib"
  docker info >/dev/null 2>&1
}

status() {
  if docker info >/dev/null 2>&1; then
    echo "Docker daemon: up ($(docker context show))"
    local memory_bytes memory_gib
    memory_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
    memory_gib="$(awk -v bytes="$memory_bytes" 'BEGIN { printf "%.1f", bytes / 1024 / 1024 / 1024 }')"
    echo "Docker memory: ${memory_gib} GiB"
    return 0
  fi
  echo "Docker daemon: down (start it, or run 'mise run start' to start Colima)"
  return 1
}

command_name="${1:-}"
case "$command_name" in
  profile) colima_profile ;;
  ensure) ensure "${2:-4}" ;;
  status) status ;;
  *) usage ;;
esac