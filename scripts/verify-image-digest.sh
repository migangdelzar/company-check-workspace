#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: verify-image-digest.sh IMAGE@sha256:DIGEST}"
if [[ ! "$image" =~ ^[^[:space:]@]+@sha256:[0-9a-fA-F]{64}$ ]]; then
  printf 'image must be pinned by a 64-hex digest: %s\n' "$image" >&2
  exit 2
fi

command -v docker >/dev/null || { printf 'docker is required\n' >&2; exit 127; }
actual="$(docker buildx imagetools inspect "$image" --format '{{json .Manifest.Digest}}' | tr -d '"')"
expected="${image##*@}"
[ "$actual" = "$expected" ] || { printf 'digest mismatch: expected %s, got %s\n' "$expected" "$actual" >&2; exit 1; }
printf '%s\n' "$image"
