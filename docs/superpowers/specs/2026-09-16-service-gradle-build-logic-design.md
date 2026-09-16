# Service Gradle Build-Logic Refactor Design

## Goal

Organize the service build into an included `build-logic` build with focused
convention plugins, provide a fast unit-oriented path for local iteration, and
keep the complete validation gate available for release/CI use.

## Scope and boundaries

- `company-check-service` remains an independent repository.
- Parent workspace Compose scripts remain parent-owned and are not removed.
- The service `mise.toml` command aliases are removed because Gradle is the
  service build source of truth.
- Existing HTTP, provider, persistence, resilience, cache, Docker, and
  coverage behavior is preserved unless a focused audit proves a requested
  contract is missing.
- The downloaded `ai-rules-hub` Java rules are adopted for naming, imports,
  constructor injection, boundary validation, exception handling, testing,
  and documentation. Its JPA recommendations are explicitly not adopted;
  this service uses JDBC by design and keeps the domain framework-free.

## Build structure

```text
company-check-service/
├── settings.gradle.kts
├── build.gradle.kts
├── build-logic/
│   ├── settings.gradle.kts
│   ├── build.gradle.kts
│   └── src/main/kotlin/
│       ├── com.incode.java-conventions.gradle.kts
│       ├── com.incode.testing-conventions.gradle.kts
│       ├── com.incode.quality-conventions.gradle.kts
│       ├── com.incode.contract-conventions.gradle.kts
│       ├── com.incode.container-conventions.gradle.kts
│       └── com.incode.service-conventions.gradle.kts
└── gradle/libs.versions.toml
```

The service applies the catalog-backed Spring Boot plugin directly in the root
build, followed by `com.incode.service-conventions`. The convention plugin
composes Java, test suites, quality tasks, OpenAPI contract tasks, and image
tasks. Service-specific dependency choices and provider/image properties remain
in the root build.

## Task model

- `fastCheck`: compile production and test sources, run unit tests, and run
  local formatting/static checks that do not require PostgreSQL, Redis,
  provider processes, OpenAPI CLI downloads, or Docker.
- `qualityGate`: existing complete gate, including integration/contract/E2E
  suites, OpenAPI validation, JaCoCo report and 80% focused coverage
  verification.
- `image` and `imageSmoke`: service-owned container operations.

All custom tasks have explicit groups and descriptions so `./gradlew tasks`
is organized by type rather than by implementation location.

## Verification

The refactor is verified with:

1. Build-logic compilation and Gradle task discovery.
2. Service `fastCheck`.
3. Service `qualityGate` when all required local tools/services are available.
4. Static contract checks proving the canonical API fields, annotations,
   framework-free domain, persistence source of truth, resilience policies,
   cache/coordination configuration, and provider-compatible routes remain.
5. Parent workspace validation separately, without changing parent-owned
   Compose scripts.

## Design rationale

Gradle's current guidance recommends an included `build-logic` build and
convention plugins over a large root script or `buildSrc`. The split is kept
focused: it removes duplicated configuration without introducing multi-module
application code or speculative abstractions.
