# Company Check Workspace

Company Check is a small verification platform composed of:

- \`company-check-service/\` — Spring Boot 4 service, Java 25, Gradle Kotlin DSL.
- \`company-check-provider/\` — Bun/Fastify deterministic provider simulator.
- \`compose*.yaml\` — single-node, distributed, and performance topologies.
- \`docs/\` — ADRs and current architecture documentation.

The service accepts a verification ID and company query, coordinates duplicate
work, calls the appropriate provider, stores the result in PostgreSQL, and
exposes read-only retrieval.

See [architecture](docs/architecture/README.md) and
[ADRs](docs/adr/README.md) for the design rationale.

## Requirements

- Docker Engine and Docker Compose v2.
- Java 25 for the Gradle service build.
- Bun for provider development checks.
- \`mise\` is optional and provides workspace task aliases.
- Git submodules initialized recursively.

Initialize the workspace with:

\`\`\`sh
git submodule update --init --recursive
\`\`\`

## Fast service verification

\`\`\`sh
./company-check-service/gradlew -p company-check-service fastCheck
\`\`\`

This runs formatting, Checkstyle, static analysis, unit tests, and coverage
checks without external services.

The complete service gate uses PostgreSQL and Redis Testcontainers. For Colima
or another VM-backed Docker context:

\`\`\`sh
export DOCKER_HOST="$(docker context inspect "$(docker context show)" --format '{{.Endpoints.docker.Host}}')"
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
./company-check-service/gradlew -p company-check-service qualityGate \
  --no-parallel --max-workers=1
\`\`\`

The Gradle convention forwards these values to every test worker. Equivalent
Gradle properties are \`testcontainersDockerHost\` and
\`testcontainersDockerSocketOverride\`.

Provider checks are independent:

\`\`\`sh
(cd company-check-provider && bun install --frozen-lockfile && bun run quality)
\`\`\`

## Compose image configuration

For local development, build local images and use local tags:

\`\`\`sh
docker build -t company-check-provider:local company-check-provider
./company-check-service/gradlew -p company-check-service image \
  -PpaketoBuilderImage=<approved-builder@sha256:64-hex-digest> \
  -PpaketoRunImage=<approved-run@sha256:64-hex-digest> \
  -PimageName=company-check-service:local
\`\`\`

Copy the workspace environment template:

\`\`\`sh
cp .env.example .env
\`\`\`

For local Compose, set these values in \`.env\`:

\`\`\`dotenv
COMPANY_CHECK_SERVICE_IMAGE=company-check-service:local
COMPANY_CHECK_PROVIDER_IMAGE=company-check-provider:local
POSTGRES_IMAGE=postgres:16-alpine
REDIS_IMAGE=redis:7-alpine
LOCUST_IMAGE=locustio/locust:2.32.10
COMPANY_CHECK_DB_PASSWORD=change-me-locally
\`\`\`

For CI/release validation, use approved immutable \`@sha256:\` references for
all five image variables. The all-zero values in \`.env.example\` are
placeholders and must not be used as actual images.

Validate the rendered configuration:

\`\`\`sh
docker compose -f compose.yaml -f compose.single.yaml config
\`\`\`

## Single-node topology

Single node uses one backend replica, PostgreSQL, and the two provider
simulators. Coordination and rate limiting stay in process; Redis is not
started.

\`\`\`sh
docker compose -f compose.yaml -f compose.single.yaml up -d --scale backend=1
docker compose -f compose.yaml -f compose.single.yaml ps
curl --fail http://localhost:8080/actuator/health
\`\`\`

Start a verification with the current API shape (\`GET\`, not \`POST\`):

\`\`\`sh
verification_id="$(uuidgen)"
curl --fail --get http://localhost:8080/backend-service \
  --data-urlencode "verificationId=$verification_id" \
  --data-urlencode "query=Acme"
curl --fail http://localhost:8080/verifications/"$verification_id"
\`\`\`

Stop it without removing database volumes:

\`\`\`sh
docker compose -f compose.yaml -f compose.single.yaml down --remove-orphans
\`\`\`

## Distributed topology

Distributed mode starts Redis and two backend replicas. Redis provides shared
coordination, cache/rate-limit state, and the expiration lease; PostgreSQL
remains authoritative.

\`\`\`sh
docker compose -f compose.yaml -f compose.distributed.yaml up -d --scale backend=2
docker compose -f compose.yaml -f compose.distributed.yaml ps
\`\`\`

The distributed overlay deliberately removes the host-published backend port,
so no single replica is presented as a load balancer. Use Locust or another
client on the internal Compose network. Stop it with:

\`\`\`sh
docker compose -f compose.yaml -f compose.distributed.yaml down --remove-orphans
\`\`\`

## Locust performance smoke test

The service-owned runner starts the performance Compose stack, waits for the
backend health check, runs the version-controlled Locust scenario, writes
HTML/CSV artifacts, and tears the stack down on exit:

\`\`\`sh
./company-check-service/performance/run.sh
\`\`\`

Defaults are five users, one user per second spawn rate, and 30 seconds.
Override them without editing the scenario:

\`\`\`sh
PERFORMANCE_USERS=10 PERFORMANCE_DURATION=60s \
  ./company-check-service/performance/run.sh
\`\`\`

Artifacts are written to \`.performance-artifacts/\`.

## Workspace task aliases

With \`mise\` installed:

\`\`\`sh
mise run validate
mise run service-full
mise run compose-up
mise run compose-distributed
mise run performance
mise run compose-down
\`\`\`

## Troubleshooting

### Compose rejects an image variable

For local runs, replace the all-zero values from \`.env.example\` with local
tags. For CI/release runs, use approved immutable digest references.

### Testcontainers cannot find Docker

Check \`docker context show\` and \`docker info\`. Export \`DOCKER_HOST\` to
the active context endpoint. For Colima, also export
\`TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock\`; the host socket
path is not mountable from inside the Colima VM.

### Distributed backend is not reachable from the host

That is intentional. The distributed overlay has no host port mapping. Use
Locust, \`docker compose run\` on the internal network, or a temporary local
Compose override that publishes one backend replica for debugging.

### Provider calls fail

Check service health and logs:

\`\`\`sh
docker compose ps
docker compose logs --no-color backend free-provider premium-provider
\`\`\`

## Documentation

- [Architecture overview](docs/architecture/overview.md)
- [Request flow](docs/architecture/request-flow.md)
- [Expiration flow](docs/architecture/expiration-flow.md)
- [Deployment topologies](docs/architecture/deployment.md)
- [Testing and performance](docs/architecture/testing.md)
- [Architecture Decision Records](docs/adr/README.md)
- [Image contract](company-check-service/docs/image-contract.md)
