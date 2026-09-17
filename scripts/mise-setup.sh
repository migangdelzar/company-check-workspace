#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/mise-setup.sh <jvm|native>" >&2
}

die() {
  echo "mise setup failed: $*" >&2
  exit 1
}

variant="${1:-}"
if [[ "$variant" != "jvm" && "$variant" != "native" ]]; then
  usage
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
memory_gib=4
if [[ "$variant" == "native" ]]; then
  memory_gib=12
fi

default_paketo_builder_image='paketobuildpacks/builder-jammy-base@sha256:aadea5426b08ec201d62a74ac46b61c0452b9bd139806f071e4a81e362a43d83'
default_paketo_run_image='paketobuildpacks/run-jammy-base@sha256:03a974a6e7b563878429117943f14139ff29f0f3d02aa7e3d3ab0ae862908168'

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' is not on PATH; run 'mise install --include-lazy' first"
}

for command_name in bun docker docker-compose curl; do
  require_command "$command_name"
done

if [[ ! -f "$repo_root/.env" ]]; then
  [[ -f "$repo_root/.env.example" ]] || die "missing .env.example"
  cp "$repo_root/.env.example" "$repo_root/.env"
  echo "Created .env from .env.example"
fi

properties_file="$repo_root/company-check-service/gradle.properties"

paketo_reference() {
  local property_name="$1" environment_name="$2" default_image="$3" value
  value="${!environment_name-}"
  if [[ -z "$value" && -f "$properties_file" ]]; then
    value="$(sed -n "s/^${property_name}=//p" "$properties_file" | head -n 1)"
  fi
  if [[ -z "$value" || "$value" == *'<64-hex-digest>'* ]]; then
    value="$default_image"
  fi
  [[ "$value" =~ ^[^@[:space:]]+@sha256:[0-9A-Fa-f]{64}$ ]] || {
    die "$environment_name must be an immutable image reference ending in @sha256:<64 hex digits>"
  }
  printf -v "$environment_name" '%s' "$value"
}

paketo_reference paketoBuilderImage PAKETO_BUILDER_IMAGE "$default_paketo_builder_image"
paketo_reference paketoRunImage PAKETO_RUN_IMAGE "$default_paketo_run_image"

if ! docker info >/dev/null 2>&1; then
  if command -v colima >/dev/null 2>&1; then
    echo "Docker is unavailable; starting Colima with ${memory_gib} GiB for the $variant setup"
    colima start --cpu 4 --memory "$memory_gib"
  fi
fi

docker info >/dev/null 2>&1 || die "Docker is unavailable; start Docker Desktop/Engine or install and start Colima"

memory_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || true)"
if [[ ! "$memory_bytes" =~ ^[0-9]+$ ]]; then
  die "could not determine active Docker memory; check the Docker daemon before running the $variant setup"
fi

required_bytes=$((memory_gib * 1024 * 1024 * 1024))
if (( memory_bytes < required_bytes )); then
  detected_gib="$(awk -v bytes="$memory_bytes" 'BEGIN { printf "%.1f", bytes / 1024 / 1024 / 1024 }')"
  die "active Docker memory is ${detected_gib} GiB; increase the Docker/Colima memory allocation to at least ${memory_gib} GiB for the $variant setup, then retry"
fi

echo "Using ${memory_gib} GiB minimum Docker memory for the $variant image setup"

(
  cd "$repo_root/company-check-provider"
  bun install --frozen-lockfile
  bun run quality
)
docker build -t company-check-provider:local "$repo_root/company-check-provider"

gradle_args=(
  -p "$repo_root/company-check-service"
  image
  "-PimageVariant=$variant"
  -PimageName=company-check-service:local
  "-PpaketoBuilderImage=$PAKETO_BUILDER_IMAGE"
  "-PpaketoRunImage=$PAKETO_RUN_IMAGE"
  --no-daemon
  --no-parallel
  --max-workers=1
  --console=plain
)
if [[ "$variant" == "native" ]]; then
  gradle_args+=(-PnativeOptimization=b)
fi
"$repo_root/company-check-service/gradlew" "${gradle_args[@]}"

cd "$repo_root"
docker-compose -f compose.yaml -f compose.single.yaml config >/dev/null
docker-compose -f compose.yaml -f compose.single.yaml up -d --scale backend=1

health_url="http://localhost:8080/actuator/health"
for attempt in $(seq 1 120); do
  if curl --fail --silent --show-error "$health_url" >/dev/null 2>&1; then
    echo "Single-node stack is healthy"
    echo "Service image: company-check-service:local"
    echo "Provider image: company-check-provider:local"
    echo "Health URL: $health_url"
    exit 0
  fi
  sleep 1
done

echo "Timed out waiting for $health_url" >&2
docker-compose -f compose.yaml -f compose.single.yaml ps --all >&2 || true
docker-compose -f compose.yaml -f compose.single.yaml logs --no-color --tail=80 backend free-provider premium-provider postgres >&2 || true
exit 1
