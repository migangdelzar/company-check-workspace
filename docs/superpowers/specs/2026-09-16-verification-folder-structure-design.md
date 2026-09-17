# Verification Service Folder Structure Design

| Field | Detail |
|---|---|
| Scope | Java service package structure |
| Date | 2026-09-16 |
| Status | Proposed; design approved in conversation, pending spec review |

## Goal

Make the inner packages explain business responsibility and dependency
direction without mixing DDD classification folders, functional-style names,
and technical concerns. Preserve the current service behavior, HTTP contracts,
database schema, provider contracts, and hexagonal dependency direction.

## Current problem

The top-level `domain`, `application`, and `adapter` boundaries are useful, but
some inner packages describe implementation vocabulary rather than ownership:

- `domain/aggregate`, `domain/entity`, `domain/type`, `domain/valueobject`, and
  `domain/policy` scatter one business model across generic DDD categories.
- `adapter/config` contains both Spring configuration and provider behavior.
- `adapter/out/expiration` contains a scheduler that drives the application and
  is therefore inbound, not outbound.
- `application/context` and `adapter/out/observability` are empty.

## Recommended structure

```text
com/incode/verification/
├── domain/
│   ├── company/
│   │   └── Company.java
│   ├── identity/
│   │   └── UuidV7.java
│   ├── provider/
│   │   ├── FallbackPolicy.java
│   │   ├── ProviderFailure.java
│   │   ├── ProviderResult.java
│   │   └── ProviderType.java
│   ├── query/
│   │   ├── InvalidQueryException.java
│   │   └── NormalizedQuery.java
│   └── verification/
│       ├── Verification.java
│       ├── VerificationState.java
│       └── VerificationStatus.java
├── application/
│   ├── port/
│   │   ├── in/
│   │   │   ├── ExpireVerificationsUseCase.java
│   │   │   ├── GetVerificationUseCase.java
│   │   │   ├── StartVerificationCommand.java
│   │   │   └── StartVerificationUseCase.java
│   │   └── out/
│   │       ├── CoordinationPort.java
│   │       ├── ProviderLookupPort.java
│   │       └── VerificationRepository.java
│   ├── result/
│   │   └── VerificationResult.java
│   └── service/
│       ├── CoordinationUnavailableException.java
│       ├── ExpireVerificationsService.java
│       ├── GetVerificationService.java
│       ├── ProviderResolutionService.java
│       ├── ProviderSubmissionException.java
│       ├── StartVerificationService.java
│       ├── VerificationConflictException.java
│       ├── VerificationException.java
│       ├── VerificationNotFoundException.java
│       ├── VerificationReconciliation.java
│       ├── VerificationRecoveryService.java
│       └── VerificationStoreService.java
├── adapter/
│   ├── in/
│   │   ├── scheduling/
│   │   │   └── VerificationExpirationScheduler.java
│   │   └── web/
│   │       ├── ApiExceptionHandler.java
│   │       ├── BackendServiceController.java
│   │       ├── BackendServiceRequest.java
│   │       ├── CompanyResponse.java
│   │       ├── VerificationController.java
│   │       └── VerificationResponse.java
│   └── out/
│       ├── coordination/
│       │   ├── LocalCoordinationAdapter.java
│       │   ├── RedisCoordinationAdapter.java
│       │   └── RedisLease.java
│       ├── persistence/
│       │   ├── JdbcVerificationRepository.java
│       │   ├── VerificationEntity.java
│       │   └── VerificationStateCodec.java
│       ├── provider/
│       │   ├── DistributedFreeProvider.java
│       │   ├── DistributedPremiumProvider.java
│       │   ├── FreeProvider.java
│       │   ├── PremiumProvider.java
│       │   ├── ProviderContractException.java
│       │   ├── ProviderEndpointProperties.java
│       │   ├── ProviderProperties.java
│       │   ├── ProviderRateLimitExceededException.java
│       │   ├── ProviderResponseMapper.java
│       │   ├── ProviderTransientException.java
│       │   ├── ResilientProvider.java
│       │   └── RestClientProviderAdapter.java
│       └── ratelimit/
│           ├── ProviderRateLimiter.java
│           └── RedisProviderRateLimiter.java
└── configuration/
    ├── ApplicationConfiguration.java
    ├── CacheConfiguration.java
    ├── CoordinationConfiguration.java
    ├── CoordinationProperties.java
    ├── DatabaseProperties.java
    ├── DatabaseRetryProperties.java
    ├── DistributedProviderResilienceConfiguration.java
    ├── LocalCoordinationConfiguration.java
    ├── ObservabilityConfiguration.java
    ├── PersistenceConfiguration.java
    ├── ProviderHttpConfiguration.java
    ├── ProviderRateLimitProperties.java
    ├── ProviderResilienceConfiguration.java
    ├── VerificationCacheExpiry.java
    └── VerificationProperties.java
```

Class names do not change as part of this work.

## Package ownership

### Domain

Use business concepts instead of DDD category names:

| Package | Classes | Responsibility |
|---|---|---|
| `domain.company` | `Company` | Company data and company invariants |
| `domain.identity` | `UuidV7` | Domain identifier generation |
| `domain.provider` | `FallbackPolicy`, `ProviderFailure`, `ProviderResult`, `ProviderType` | Provider outcomes, provider identity, and fallback rule |
| `domain.query` | `NormalizedQuery`, `InvalidQueryException` | Query normalization and query invariant errors |
| `domain.verification` | `Verification`, `VerificationState`, `VerificationStatus` | Verification lifecycle and legal state transitions |

The domain remains framework-free. A class's DDD role is expressed by its
behavior and API, not by an `aggregate`, `entity`, `type`, or `valueobject`
folder.

### Application

Keep the existing application structure because it expresses dependency
direction clearly:

- `port/in` contains inbound use-case contracts and commands.
- `port/out` contains outbound contracts required by the application.
- `service` contains use-case orchestration and application-level exceptions.
- `result` contains the application result mapped by inbound adapters.
- Remove the empty `context` package.

No application class moves solely to make the tree symmetrical. The existing
names are sufficiently specific for the current service.

### Adapters

Keep `adapter/in` and `adapter/out` because they make the hexagonal direction
explicit:

- `adapter/in/web` contains HTTP controllers, request/response models, and the
  HTTP exception handler.
- Move `VerificationExpirationScheduler` from `adapter/out/expiration` to
  `adapter/in/scheduling`; a scheduler invokes an application use case.
- Keep coordination, persistence, provider, and rate-limit implementations in
  `adapter/out` because they call external systems or implement outbound ports.
- Move provider implementations currently under `adapter/config` to
  `adapter/out/provider`:
  `FreeProvider`, `PremiumProvider`, `DistributedFreeProvider`,
  `DistributedPremiumProvider`, `ResilientProvider`, and
  `ProviderRateLimitExceededException`.

### Configuration

Move the current `adapter/config` package to the top-level
`configuration` package. It owns Spring wiring, profiles, configuration
properties, HTTP-client construction, persistence beans, cache setup, and
observability setup. It must not own provider behavior.

The following remain in `configuration`:

- `ApplicationConfiguration`
- `CacheConfiguration`
- `CoordinationConfiguration`
- `CoordinationProperties`
- `DatabaseProperties`
- `DatabaseRetryProperties`
- `DistributedProviderResilienceConfiguration`
- `LocalCoordinationConfiguration`
- `ObservabilityConfiguration`
- `PersistenceConfiguration`
- `ProviderHttpConfiguration`
- `ProviderRateLimitProperties`
- `ProviderResilienceConfiguration`
- `VerificationCacheExpiry`
- `VerificationProperties`

## Dependency direction

```text
configuration ──wires──> application + adapters
adapter/in ────────────> application/port/in
application ───────────> domain + application/port/out
adapter/out ───────────> application/port/out + domain
domain ────────────────> no Spring/application/adapter packages
```

Package moves must not introduce new runtime dependencies or framework types
into the domain.

## Migration rules

1. Move files with `git mv` so history remains discoverable.
2. Update each moved file's `package` declaration.
3. Update imports and fully qualified references across main and test sources.
4. Remove the empty `application/context` and `adapter/out/observability`
   directories.
5. Do not rename classes, change public methods, alter annotations, or modify
   business logic in this structural change.
6. Do not retain compatibility packages; the old package names should have no
   remaining references after migration.

## Verification

- Search main and test sources for old package names; expect zero results.
- Confirm the target package tree contains no generic DDD category folders.
- Run the service's `fastCheck` task.
- Run the architecture tests, including Modulith and hexagonal dependency
  checks.
- Confirm HTTP, persistence, provider, coordination, and configuration tests
  remain green.

## Non-goals

- No behavior or business-rule changes.
- No API, DB schema, migration, provider contract, or configuration-key changes.
- No conversion to feature-first packaging.
- No new abstraction, facade, registry, or framework dependency.
- No broad class renaming; this task changes package ownership only.
