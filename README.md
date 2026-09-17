# Company Check Workspace

Company Check is a small verification platform composed of:

- `company-check-service/` — Spring Boot 4 service, Java 25, Gradle Kotlin DSL.
- `company-check-provider/` — Bun/Fastify deterministic provider simulator.
- `compose*.yaml` — single-node, distributed, and performance topologies.
- `docs/` — ADRs and current architecture documentation.

The service accepts a verification ID and company query, coordinates duplicate
work, calls the appropriate provider, stores the result in PostgreSQL, and
exposes read-only retrieval.

This README is the setup guide: it covers prerequisites, local image builds,
Compose profiles, health checks, API smoke calls, observability, performance,
and shutdown. For implementation detail, use the focused references:

- [Architecture index](docs/architecture/README.md) — all current architecture diagrams.
- [Whole request flow](docs/architecture/request-flow.md) — admission, idempotency, coordination, provider calls, persistence, and retrieval.
- [Resilience and fallback](docs/architecture/resilience.md) — filters, limiters, retries, circuits, bulkheads, pools, caches, leases, and failure handling.
- [Runtime architecture](docs/architecture/runtime-architecture.md) — package boundaries, build artifacts, single/distributed topologies, and observability.
- [ADRs](docs/adr/README.md) — the design rationale and trade-offs.

For the complete prerequisite, image-build, Compose startup, health-check,
profile, and shutdown sequence, see [Starting the application](docs/architecture/startup.md).

The backend source is a conventional layered Spring Boot module: controllers
call services; services use repository and provider-client contracts; `config`
wires the profile-specific implementations. The deterministic Bun/Fastify
provider remains a separate deployable simulator.

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

The service keeps Temurin suitable for regular JVM builds and automatically
provisions a native-image-capable GraalVM toolchain for local
`nativeCompile`. For the Compose path, build the native OCI image through
Paketo by adding `-PimageVariant=native -PnativeOptimization=b` to the command
above. Paketo provisions its native toolchain inside the builder container.

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

### What happens during a request

`GET /backend-service` is handled in this order:

1. `InboundRateLimitFilter` admits the start request before controller and
   database work. Single node uses a local Resilience4j limiter; distributed
   mode uses a Redis atomic fixed-window limiter. Rejection is `429` with
   `Retry-After`; inability to coordinate admission is `503`.
2. `VerificationService` checks PostgreSQL for the verification ID. Reusing the ID
   with the same normalized query is idempotent; reusing it with a different
   query is a conflict. A new request is inserted as `IN_PROGRESS`.
3. `VerificationService` acquires a query lease. Single node uses an in-process
   lock; distributed mode uses Redis. A competing request waits for a shared
   terminal result or re-checks PostgreSQL after the bounded lease wait. This
   prevents duplicate provider work across replicas.
4. The lease owner checks PostgreSQL for a reusable completed result by
   normalized query. Only when no reusable result exists does it call the
   providers.
5. The free provider is called first through the shared Apache HttpClient 5
   pool. The call is bounded by retry, circuit-breaker, rate-limit, bulkhead,
   connection-acquisition, connect, and response-time limits. A successful
   response is mapped and normalized.
6. `Unavailable`, `Timeout`, `Malformed`, circuit-open, bulkhead-rejected,
   and quota-rejected outcomes invoke the premium provider fallback. A known
   provider `4xx` is a client error and does not silently consume premium
   capacity. If both providers fail, the final failure is returned/stored
   according to the application error policy.
7. The result is claimed and completed transactionally in PostgreSQL. Cache
   publication happens only after commit: Caffeine is used locally and Redis
   is added as shared coordination/cache state in distributed mode.

`GET /verifications/{verificationId}` is read-only. It reads the verification
lifecycle from PostgreSQL and never invokes a provider, consumes provider
quota, or acquires a provider bulkhead permit. See the [whole request flow](docs/architecture/request-flow.md)
and [resilience reference](docs/architecture/resilience.md) for sequence
diagrams and failure semantics.

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

To exercise the native image across two Redis-coordinated backend replicas:

```sh
./company-check-service/gradlew -p company-check-service image \
  -PpaketoBuilderImage=<approved-builder@sha256:64-hex-digest> \
  -PpaketoRunImage=<approved-run@sha256:64-hex-digest> \
  -PimageVariant=native \
  -PnativeOptimization=b \
  -PimageName=company-check-service:native-local
COMPANY_CHECK_SERVICE_IMAGE=company-check-service:native-local \
PERFORMANCE_TOPOLOGY=distributed \
  ./company-check-service/performance/run.sh
```

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
- [Runtime architecture](docs/architecture/runtime-architecture.md)
- [Resilience and fallback](docs/architecture/resilience.md)
- [Request flow](docs/architecture/request-flow.md)
- [Expiration flow](docs/architecture/expiration-flow.md)
- [Deployment topologies](docs/architecture/deployment.md)
- [Testing and performance](docs/architecture/testing.md)
- [Architecture Decision Records](docs/adr/README.md)
- [Image contract](company-check-service/docs/image-contract.md)
