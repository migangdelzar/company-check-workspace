#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: verify-image-digest.sh IMAGE@sha256:DIGEST}"
case "$image" in
  *@sha256:[0-9a-fA-F]*) ;;
  *) printf 'image must be pinned by digest: %s\n' "$image" >&2; exit 2 ;;
esac

command -v docker >/dev/null || { printf 'docker is required\n' >&2; exit 127; }
actual="$(docker buildx imagetools inspect "$image" --format '{{json .Manifest.Digest}}' | tr -d '"')"
expected="${image##*@}"
[ "$actual" = "$expected" ] || { printf 'digest mismatch: expected %s, got %s\n' "$expected" "$actual" >&2; exit 1; }
printf '%s\n' "$image"
