#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: scripts/mise-setup.sh <jvm|native> [--build-only] [--observability]" >&2
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
build_only=0
observability=0
for option in "${@:2}"; do
  case "$option" in
    --build-only) build_only=1 ;;
    --observability) observability=1 ;;
    *) usage; exit 2 ;;
  esac
done

service_image="${COMPANY_CHECK_SERVICE_IMAGE:-company-check-service:local}"
export COMPANY_CHECK_SERVICE_IMAGE="$service_image"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
memory_gib=4
if [[ "$variant" == "native" ]]; then
  memory_gib=11
fi

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' is not on PATH; run 'mise run install'"
}

for command_name in bun docker docker-compose curl; do
  require_command "$command_name"
done

[[ -f "$repo_root/company-check-service/gradlew" ]] || die "company-check-service submodule is not initialized; run 'mise run install'"
[[ -f "$repo_root/company-check-provider/Dockerfile" ]] || die "company-check-provider submodule is not initialized; run 'mise run install'"

if [[ ! -f "$repo_root/.env" ]]; then
  [[ -f "$repo_root/.env.example" ]] || die "missing .env.example"
  cp "$repo_root/.env.example" "$repo_root/.env"
  echo "Created .env from .env.example"
fi

if ! docker info >/dev/null 2>&1; then
  if command -v colima >/dev/null 2>&1; then
    profile="$("$repo_root/scripts/mise-docker.sh" profile)"
    echo "Docker is unavailable; starting Colima profile '$profile' with ${memory_gib} GiB for the $variant setup"
    colima start -p "$profile" --cpu 4 --memory "$memory_gib"
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
  bootBuildImage
  "-PimageVariant=$variant"
  "-PimageName=$service_image"
  --no-daemon
  --no-parallel
  --max-workers=1
  --console=plain
)
"$repo_root/company-check-service/gradlew" "${gradle_args[@]}"

if (( build_only )); then
  echo "Images built (services not started):"
  echo "Service image: $service_image"
  echo "Provider image: company-check-provider:local"
  exit 0
fi

cd "$repo_root"
compose_files=(-f compose.yaml -f compose.single.yaml)
compose_description="Single-node stack"
if (( observability )); then
  compose_files+=(-f compose.observability.yaml --profile observability)
  compose_description="Complete stack with observability"
fi
docker-compose "${compose_files[@]}" up -d --scale backend=1

health_url="http://localhost:8080/actuator/health"
for attempt in $(seq 1 120); do
  if curl --fail --silent --show-error "$health_url" >/dev/null 2>&1; then
    if (( ! observability )); then
      echo "$compose_description is healthy"
      echo "Service image: $service_image"
      echo "Provider image: company-check-provider:local"
      echo "Health URL: $health_url"
      exit 0
    fi

    grafana_auth="${GRAFANA_ADMIN_USER:-admin}:${GRAFANA_ADMIN_PASSWORD:-admin}"
    if curl --fail --silent --show-error http://localhost:9090/-/ready >/dev/null 2>&1 \
      && curl --fail --silent --show-error --user "$grafana_auth" http://localhost:3000/api/health >/dev/null 2>&1 \
      && curl --fail --silent --show-error http://localhost:3100/ready >/dev/null 2>&1 \
      && curl --fail --silent --show-error http://localhost:3200/ready >/dev/null 2>&1; then
      echo "$compose_description is healthy"
      echo "Service image: $service_image"
      echo "Provider image: company-check-provider:local"
      echo "Health URL: $health_url"
      echo "Grafana URL: http://localhost:3000"
      exit 0
    fi
  fi
  sleep 1
done

echo "Timed out waiting for $health_url" >&2
  docker-compose "${compose_files[@]}" ps --all >&2 || true
  docker-compose "${compose_files[@]}" logs --no-color --tail=80 backend free-provider premium-provider postgres >&2 || true
exit 1
