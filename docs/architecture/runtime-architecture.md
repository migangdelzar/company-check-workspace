# Runtime Architecture

This document describes the current source layers, build artifacts, Compose
topologies, observability overlay, and resource bounds. Source code and Compose
files remain authoritative if implementation changes before this page does.

## Backend layers

```mermaid
flowchart TB
  Config[config\nSpring composition root]
  Controller[controller\nHTTP + scheduling]
  Service[service\nworkflow + service/model]
  Repository[repository\nJDBC + coordination + limits]
  Client[client\nprovider HTTP + DTOs]
  Mapper[mapper\nexplicit conversions]
  Exception[exception\nerrors + HTTP mapping]

  Config --> Controller
  Config --> Service
  Config --> Repository
  Config --> Client
  Controller --> Service
  Service --> Repository
  Service --> Client
  Controller -. DTO mapping .-> Mapper
  Repository -. entity/state mapping .-> Mapper
  Client -. provider mapping .-> Mapper
  Controller -. translated failures .-> Exception
  Service -. service failures .-> Exception
```

| Package | Responsibility | Boundary rule |
|---|---|---|
| `config` | Spring wiring, profiles, properties, HTTP clients, resilience, persistence, cache, rate limits, and native hints | Composes implementations; contains no workflow decisions |
| `controller` | `BackendServiceController`, `VerificationController`, `InboundRateLimitFilter`, `VerificationExpirationScheduler`, and API DTOs | Does not call repositories or provider clients directly |
| `service` | `VerificationService`, `ProviderService`, `VerificationStoreService`, `VerificationRecoveryService`, `ExpirationService`, and `service/model` | Does not depend on MVC, JDBC, Redis, HTTP client internals, entities, or provider DTOs |
| `repository` | `VerificationRepository`, `JdbcVerificationRepository`, entities, coordination, leases, cache, and rate-limit implementations | Owns external state and persistence entities |
| `client` | `ProviderClient`, typed FREE/PREMIUM clients, provider transport handling, and client DTOs | Owns provider wire types and HTTP integration |
| `mapper` | `VerificationMapper`, `ProviderMapper`, `VerificationStateMapper`, and reconciliation mapping | Performs small, explicit representation conversions |
| `exception` | Business/integration exception hierarchy and `GlobalExceptionHandler` | Keeps HTTP error translation at the boundary |

The single `verification` Modulith module and layered ArchUnit tests protect
these rules. The legacy `adapter`, `application`, and `domain` production
packages were removed by the layered migration.

## Build and artifact pipeline

```mermaid
flowchart LR
  Source[Git workspace + provider submodule]
  ServiceBuild[Gradle service build\nJava 25 + build-logic]
  ProviderBuild[Bun provider build\nTypeScript -> dist]
  Checks[Quality artifacts\nformatting, analysis, tests, coverage, OpenAPI]
  BootJar[Spring Boot executable JAR]
  ServiceImage[Paketo OCI service image\nJVM or native]
  ProviderImage[Provider OCI image\nDockerfile + Bun runtime]
  Compose[Compose topology\nsingle or distributed]
  Runtime[Backend + dependencies]

  Source --> ServiceBuild --> Checks
  Source --> ProviderBuild --> Checks
  ServiceBuild --> BootJar --> ServiceImage
  ProviderBuild --> ProviderImage
  ServiceImage --> Compose
  ProviderImage --> Compose
  Compose --> Runtime
```

### Service artifacts

- Gradle Kotlin DSL and included `build-logic` own build conventions.
- Dependency locking/verification, Spotless, Checkstyle, Detekt, Error Prone,
  NullAway, JaCoCo, and OpenAPI validation run through focused gates.
- `fastCheck` runs local formatting, static analysis, unit tests, and coverage.
- `qualityGate` adds contract tests, integration tests, OpenAPI validation, and
  build-logic checks.
- `bootJar` creates the executable Spring Boot artifact.
- `image` delegates OCI creation to Spring Boot Paketo integration.
- `imageSmoke` verifies startup and the non-root runtime contract.

### Provider artifacts

- `bun run build` compiles TypeScript into `dist`.
- The provider Dockerfile installs from `bun.lock`, copies runtime fixtures and
  scenarios, and runs as the `bun` user.
- One image runs as both the FREE and PREMIUM deterministic simulators using
  different `PROVIDER_TIER` and scenario-file settings.

### Compose inputs

| File | Role |
|---|---|
| `compose.yaml` | Backend, provider simulators, PostgreSQL, internal network, debug backend, and optional Locust |
| `compose.single.yaml` | `single-node` profile and host-published backend port |
| `compose.distributed.yaml` | `distributed` profile, Redis, scaled replicas, and no host port for individual backends |
| `compose.observability.yaml` | Prometheus, Grafana, Tempo, Loki, Alloy, and telemetry overrides |

Development may use local tags. CI/release validation requires digest-pinned
backend, provider, PostgreSQL, Redis, and Locust references; the performance
runner resolves local tags to repository digests before starting Compose.

## Single-node architecture

```mermaid
flowchart TB
  Client[API client\nlocalhost:8080]
  Backend[backend\nsingle-node profile]
  Filter[InboundRateLimitFilter\nlocal Resilience4j limiter]
  Controller[Controllers]
  Verification[VerificationService]
  Provider[ProviderService]
  Store[VerificationStoreService]
  Recovery[VerificationRecoveryService]
  Expiration[ExpirationService]
  Caffeine[(Caffeine\nbounded L1 cache)]
  JDBC[JdbcVerificationRepository\nJdbcClient + HikariCP]
  PG[(PostgreSQL\nauthoritative verification state)]
  HTTP[RestClient + Apache HttpClient 5\nshared bounded pool]
  Free[free-provider\ninternal:3000]
  Premium[premium-provider\ninternal:3000]
  Scheduler[VerificationExpirationScheduler\nlocal lock]
  Prom[Prometheus\noptional scrape]

  Client --> Backend --> Filter --> Controller --> Verification
  Verification --> Store
  Verification --> Recovery
  Verification --> Provider --> HTTP
  Provider --> Free
  Provider --> Premium
  Store --> JDBC --> PG
  Recovery --> Caffeine
  Scheduler --> Expiration --> JDBC
  Backend -. /actuator/prometheus .-> Prom
```

Single-node does not start Redis. `LocalCoordinationRepository` and
`LocalExpirationLock` provide in-process coordination; Caffeine remains the
bounded local cache. PostgreSQL owns verification identity, status, expiry,
claims, and terminal result state.

## Distributed architecture

```mermaid
flowchart TB
  Caller[Internal caller or Locust]
  B1[backend replica 1\ndistributed profile]
  B2[backend replica 2\ndistributed profile]
  Bn[Additional replicas\noptional]
  Redis[(Redis\ncoordination + leases +\nL2 cache + rate limits)]
  PG[(PostgreSQL\nauthoritative state)]
  Free[free-provider]
  Premium[premium-provider]
  S1[Each replica schedules expiration]
  Lease[One replica owns\nexpiration lease per batch]

  Caller --> B1
  Caller --> B2
  Caller --> Bn
  B1 --> Redis
  B2 --> Redis
  Bn --> Redis
  B1 --> PG
  B2 --> PG
  Bn --> PG
  B1 --> Free
  B2 --> Free
  Bn --> Free
  B1 --> Premium
  B2 --> Premium
  Bn --> Premium
  B1 --> S1
  B2 --> S1
  Bn --> S1
  S1 --> Redis
  Redis --> Lease
```

Redis provides shared query leases, cache entries, inbound/provider fixed-window
limits, and the expiration lease. It never becomes verification truth;
PostgreSQL transactions and row locks remain authoritative. The distributed
overlay removes the host backend port; `--scale backend=N` controls replicas.

## Observability architecture

```mermaid
flowchart LR
  Backend[Backend\nActuator + Micrometer]
  Prom[Prometheus\n/actuator/prometheus scrape]
  Alloy[Grafana Alloy\nOTLP receiver + Docker log source]
  Tempo[Tempo\nlocal trace storage]
  Loki[Loki\nlocal log storage]
  Grafana[Grafana\ndashboards and queries]
  Docker[Docker socket\nread-only mount to Alloy only]

  Backend -->|metrics scrape| Prom
  Backend -->|OTLP traces| Alloy
  Docker -->|container logs| Alloy
  Alloy -->|OTLP traces| Tempo
  Alloy -->|Loki push API| Loki
  Prom --> Grafana
  Tempo --> Grafana
  Loki --> Grafana
```

The optional observability profile starts Prometheus, Grafana, Tempo, Loki, and
Alloy. The backend has no Docker socket mount. Local Loki and Tempo storage has
no authentication and is not a production topology.

## Resource boundaries

| Resource | Default bound | Purpose |
|---|---:|---|
| Hikari database connections | 16 max / 4 minimum idle | Bounds PostgreSQL connections |
| Provider HTTP connections | 100 total / 50 per route | Bounds shared provider sockets |
| Provider connection wait | 100 ms | Fails fast when the HTTP pool is exhausted |
| Provider connect / response timeout | 150 ms / 400 ms | Bounds remote call lifetime |
| Provider bulkhead | 50 calls per provider | Bounds in-flight provider work |
| Provider retries | 2 attempts, 25 ms wait | Bounds transient retry amplification |
| Inbound rate limit | 100 requests per 1 s | Protects the backend endpoint |
| Provider rate limit | 100 calls per provider per 1 s | Protects provider quotas |
| Redis coordination wait | 20 attempts × 50 ms | Bounds duplicate-query waiting |
| Expiration batch | 100 rows | Bounds each reaper transaction |
| Virtual threads | Enabled | Makes blocking waits cheaper; does not remove resource bounds |

Values are externalized in `application.yml` and profile overrides. Review any
bound change against DB capacity, provider quotas, and workload targets.
