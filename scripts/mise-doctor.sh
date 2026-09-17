#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
failures=0

echo "mise doctor"
echo

if command -v mise >/dev/null 2>&1; then
  echo "mise: $(mise --version 2>/dev/null | head -1)"
else
  echo "mise: MISSING - install it first (see GETTING_STARTED.md)" >&2
  failures=$((failures + 1))
fi

echo "tools:"
for tool in java bun docker docker-compose curl colima; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  $tool: ok"
  else
    echo "  $tool: MISSING - run 'mise run install' (or 'mise install')" >&2
    failures=$((failures + 1))
  fi
done

echo
echo "submodules:"
while read -r line; do
  [[ -n "$line" ]] || continue
  marker="${line:0:1}"
  path="$(awk '{print $2}' <<< "$line")"
  case "$marker" in
    -) echo "  $path: NOT INITIALIZED - run 'mise run install'" >&2 ;;
    +) echo "  $path: out of date (pinned commit not checked out)" >&2 ;;
    *) echo "  $path: ok" ;;
  esac
done < <(git -C "$repo_root" submodule status 2>/dev/null || true)
if (cd "$repo_root" && git submodule status 2>/dev/null | grep -q '^-'); then
  failures=$((failures + 1))
fi

echo
echo "environment:"
if [[ -f "$repo_root/.env" ]]; then
  echo "  .env: present (local values left untouched)"
else
  echo "  .env: MISSING - run 'mise run install' to create it from .env.example" >&2
  failures=$((failures + 1))
fi

echo
if "$repo_root/scripts/mise-docker.sh" status; then
  :
else
  echo "  Remediation: start Docker Desktop, or run 'mise run start'" >&2
  failures=$((failures + 1))
fi

echo
if (( failures == 0 )); then
  echo "doctor: all checks passed."
else
  echo "doctor: ${failures} issue(s) found." >&2
  exit 1
fi