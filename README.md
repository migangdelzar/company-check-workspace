# Company Check Workspace

Company Check is a small verification platform composed of:

- `company-check-service/` — Spring Boot 4 service, Java 25, Gradle Kotlin DSL.
- `company-check-provider/` — Bun/Fastify deterministic provider simulator.
- `compose*.yaml` — single-node, distributed, and performance topologies.
- `docs/` — ADRs and current architecture documentation.

The service accepts a verification ID and company query, coordinates duplicate
work, calls the appropriate provider, stores the result in PostgreSQL, and
exposes read-only retrieval.

See [architecture](docs/architecture/README.md), including the [runtime architecture](docs/architecture/runtime-architecture.md) and [resilience/fallback reference](docs/architecture/resilience.md), and
[ADRs](docs/adr/README.md) for the design rationale.

For the complete prerequisite, image-build, Compose startup, health-check,
profile, and shutdown sequence, see [Starting the application](docs/architecture/startup.md).

## Requirements

- Docker Engine and Docker Compose v2, or `mise` to install the pinned CLI,
  Compose, and Colima versions.
- Java 25 for the Gradle service build.
- Bun for provider development checks.
- `mise` is optional, but is the easiest way to install the workspace tools
  and run the common commands.
- Git submodules initialized recursively.

Initialize the workspace with:

```sh
git submodule update --init --recursive
```

Choose one Docker runtime. If Docker Desktop or Docker Engine is already
installed, let mise install only the CLI and Compose:

```sh
mise trust
mise install java bun docker-cli docker-compose
```

On macOS, if you want mise to install and manage Colima as the Docker runtime,
install all three project tools, including the lazy Colima tool:

```sh
mise trust
mise install --include-lazy
```

Then create the local environment and start the single-node stack:

```sh
cp .env.example .env
mise run start
```

`mise run start` uses an existing Docker daemon first, or starts Colima when
it is installed and Docker is unavailable. It then launches PostgreSQL, the
provider simulators, and the backend. The local `.env` is ignored by Git.

## Fast service verification

```sh
./company-check-service/gradlew -p company-check-service fastCheck
```

This runs formatting, Checkstyle, static analysis, unit tests, and coverage
checks without external services.

The complete service gate uses PostgreSQL and Redis Testcontainers. For Colima
or another VM-backed Docker context:

```sh
export DOCKER_HOST="$(docker context inspect "$(docker context show)" --format '{{.Endpoints.docker.Host}}')"
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
./company-check-service/gradlew -p company-check-service qualityGate \
  --no-parallel --max-workers=1
```

The Gradle convention forwards these values to every test worker. Equivalent
Gradle properties are `testcontainersDockerHost` and
`testcontainersDockerSocketOverride`.

Provider checks are independent:

```sh
(cd company-check-provider && bun install --frozen-lockfile && bun run quality)
```

## Compose image configuration

For local development, build local images and use local tags:

```sh
docker build -t company-check-provider:local company-check-provider
./company-check-service/gradlew -p company-check-service image \
  -PpaketoBuilderImage=<approved-builder@sha256:64-hex-digest> \
  -PpaketoRunImage=<approved-run@sha256:64-hex-digest> \
  -PimageName=company-check-service:local
```

Copy the workspace environment template:

```sh
cp .env.example .env
```

For local Compose, set these values in `.env`:

```dotenv
COMPANY_CHECK_SERVICE_IMAGE=company-check-service:local
COMPANY_CHECK_PROVIDER_IMAGE=company-check-provider:local
POSTGRES_IMAGE=postgres:16-alpine
REDIS_IMAGE=redis:7-alpine
LOCUST_IMAGE=locustio/locust:2.32.10
COMPANY_CHECK_DB_PASSWORD=change-me-locally
```

For CI/release validation, use approved immutable `@sha256:` references for
all five image variables. Local tags in `.env.example` are development
defaults, not release inputs. The performance runner resolves local images to
their local repository digests before launching Compose.

Validate the rendered configuration:

```sh
docker compose -f compose.yaml -f compose.single.yaml config
```

## Single-node topology

Single node uses one backend replica, PostgreSQL, and the two provider
simulators. Coordination and rate limiting stay in process; Redis is not
started.

```sh
docker compose -f compose.yaml -f compose.single.yaml up -d --scale backend=1
docker compose -f compose.yaml -f compose.single.yaml ps
curl --fail http://localhost:8080/actuator/health
```

Start a verification with the current API shape (`GET`, not `POST`):

```sh
verification_id="$(uuidgen)"
curl --fail --get http://localhost:8080/backend-service \
  --data-urlencode "verificationId=$verification_id" \
  --data-urlencode "query=Acme"
curl --fail http://localhost:8080/verifications/"$verification_id"
```

Stop it without removing database volumes:

```sh
docker compose -f compose.yaml -f compose.single.yaml down --remove-orphans
```

## Distributed topology

Distributed mode starts Redis and two backend replicas. Redis provides shared
coordination, cache/rate-limit state, and the expiration lease; PostgreSQL
remains authoritative.

```sh
docker compose -f compose.yaml -f compose.distributed.yaml up -d --scale backend=2
docker compose -f compose.yaml -f compose.distributed.yaml ps
```

The distributed overlay deliberately removes the host-published backend port,
so no single replica is presented as a load balancer. Use Locust or another
client on the internal Compose network. Stop it with:

```sh
docker compose -f compose.yaml -f compose.distributed.yaml down --remove-orphans
```

## Local observability

The optional observability profile adds Prometheus, Grafana, Tempo, Loki, and
Grafana Alloy. Prometheus scrapes the backend's Actuator endpoint. Micrometer
observations export traces through OTLP to Alloy and Tempo; Alloy also reads
Docker logs through a read-only socket mount and forwards them to Loki. The
Docker socket is mounted only into Alloy, never into the backend or provider.

Start it with the single-node stack:

```sh
docker compose -f compose.yaml -f compose.single.yaml \
  -f compose.observability.yaml --profile observability up -d --scale backend=1
```

Open Grafana at <http://localhost:3000> (`admin`/`admin` by default). The other
local endpoints are Prometheus at <http://localhost:9090>, Tempo at
<http://localhost:3200>, Loki at <http://localhost:3100>, and Alloy at
<http://localhost:12345>. Grafana is provisioned with Prometheus, Tempo, and
Loki datasources automatically.

The observability profile is for local development and smoke testing. Loki and
Tempo use local filesystem storage and no authentication; use the platform
deployment guidance for production.

### Docker resource sizing

These are starting allocations for Docker Desktop or Colima, including the two
provider simulators and PostgreSQL. JVM memory varies with workload; add
headroom for Locust, build tasks, and filesystem cache.

| Backend replicas | Core stack (PostgreSQL + providers) | With Redis | With full observability | Recommended Docker allocation |
|---:|---:|---:|---:|---:|
| 1 | 2 vCPU / 3 GiB | 2 vCPU / 3.5 GiB | 4 vCPU / 5 GiB | 4 vCPU / 6 GiB |
| 2 | 3 vCPU / 4 GiB | 4 vCPU / 5 GiB | 4 vCPU / 6 GiB | 6 vCPU / 8 GiB |
| 3 | 4 vCPU / 5 GiB | 5 vCPU / 6 GiB | 6 vCPU / 8 GiB | 8 vCPU / 12 GiB |
| 4 | 5 vCPU / 6 GiB | 6 vCPU / 7 GiB | 8 vCPU / 10 GiB | 8–10 vCPU / 12–16 GiB |

For the normal two-replica distributed smoke test, allocate at least 6 GiB and
4 vCPUs. Four replicas with all observability services should use at least
12 GiB. A 2 vCPU / 2 GiB Colima VM is insufficient for the distributed profile
and can OOM-kill a backend.

For Colima, stop the named VM and recreate/start it with the recommended local
allocation:

```sh
colima stop emme
colima start emme --cpu 4 --memory 4
```

The default local Colima profile is 4 vCPUs and 4 GiB. That is suitable for the
core stack and one backend; use the table above before enabling full
observability or multiple backend replicas.

Docker Desktop users should set the equivalent values under Settings →
Resources. Leave `DOCKER_HOST` unset with Docker Desktop so Docker and
Testcontainers use its default socket. Set an explicit host only for a
VM-backed context such as Colima. Compose keeps the network externally routable
so its explicitly published observability ports work; services without a
published port remain reachable only inside the Compose network. Set
`COMPOSE_INTERNAL_NETWORK=true` when host-published ports are not needed.

## Locust performance smoke test

The service-owned runner starts the performance Compose stack, waits for the
backend health check, runs the version-controlled Locust scenario, writes
HTML/CSV artifacts, and tears the stack down on exit:

```sh
./company-check-service/performance/run.sh
```

Defaults are five users, one user per second spawn rate, and 30 seconds.
Override them without editing the scenario:

```sh
PERFORMANCE_USERS=10 PERFORMANCE_DURATION=60s \
  ./company-check-service/performance/run.sh
```

Artifacts are written to `.performance-artifacts/`.

## Workspace task aliases

With `mise` installed:

```sh
mise run validate
mise run service-full
mise run provider
mise run start
mise run start-distributed
mise run performance
mise run logs
mise run stop
```

`mise run start` starts Colima when needed and launches the single-node
stack using the local values in `.env`. Build or provide the local service
and provider images first; `.env.example` contains the same safe defaults for
new checkouts.

## Troubleshooting

### Compose rejects an image variable

For local runs, build or provide the local-tagged images from `.env.example`.
For CI/release runs, use approved immutable digest references.

### Testcontainers cannot find Docker

Check `docker context show` and `docker info`. Export `DOCKER_HOST` to
the active context endpoint. For Colima, also export
`TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock`; the host socket
path is not mountable from inside the Colima VM.

### Distributed backend is not reachable from the host

That is intentional. The distributed overlay has no host port mapping. Use
Locust, `docker compose run` on the internal network, or a temporary local
Compose override that publishes one backend replica for debugging.

### Provider calls fail

Check service health and logs:

```sh
docker compose ps
docker compose logs --no-color backend free-provider premium-provider
```

## Documentation

- [Architecture overview](docs/architecture/overview.md)
- [Request flow](docs/architecture/request-flow.md)
- [Expiration flow](docs/architecture/expiration-flow.md)
- [Deployment topologies](docs/architecture/deployment.md)
- [Testing and performance](docs/architecture/testing.md)
- [Architecture Decision Records](docs/adr/README.md)
- [Image contract](company-check-service/docs/image-contract.md)
