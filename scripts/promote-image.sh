#!/usr/bin/env bash
set -euo pipefail

source_image="${1:?usage: promote-image.sh SOURCE@sha256:DIGEST TARGET:TAG}"
target_image="${2:?usage: promote-image.sh SOURCE@sha256:DIGEST TARGET:TAG}"
case "$source_image" in *@sha256:*) ;; *) printf 'promotion source must be digest-pinned\n' >&2; exit 2 ;; esac
case "$target_image" in *:*) ;; *) printf 'promotion target must include a tag\n' >&2; exit 2 ;; esac

command -v crane >/dev/null || { printf 'crane is required\n' >&2; exit 127; }
"$(dirname "$0")/verify-image-digest.sh" "$source_image"
# Copying the manifest preserves the tested bytes. This path never invokes a build.
crane copy "$source_image" "$target_image"
