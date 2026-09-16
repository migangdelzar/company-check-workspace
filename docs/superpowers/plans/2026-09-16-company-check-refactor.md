# Company Check Whole-Service Refactor

## Goal

Refactor the current `incode-company` implementation toward the approved
company-verification design while preserving the assignment API, supplied
fixture contracts, and repository boundaries.

## Constraints

- Modify only `incode-company`; never modify `incode-test`.
- Keep Java 25, Spring Boot 4.1.1, Spring Modulith 2.1.1, JDBC, PostgreSQL,
  Redis, Caffeine, Resilience4j, Bun, Fastify, and Docker Compose.
- Keep the Java domain framework-free and the HTTP/configuration boundaries
  annotation-first.
- Keep exact canonical company fields: `cin`, `name`, `registrationDate`,
  `address`, and `isActive`.
- Use Gradle as the service build/test/image/contract quality source of truth.
  Keep only parent-level shell scripts whose responsibility is Compose
  orchestration.
- Preserve deterministic provider scenarios and the supplied FREE/PREMIUM
  provider wire shapes, including PREMIUM `fullAddress`.

## Refactor slices

1. **Service flow and persistence:** ensure one provider lookup per normalized
   CIN at a time, allow later requests/polls to hydrate their own verification
   from shared terminal state, preserve idempotency by verification ID, and
   make expiry/recovery ownership-safe.
2. **Provider simulator:** use exact case-insensitive CIN indexing, validate
   scenario configuration strictly, remove duplicate defaults, and keep all
   failure actions deterministic and testable.
3. **Contracts:** make the checked-in provider OpenAPI contract match the
   implementation and fixtures; keep backend OpenAPI and client tests aligned.
4. **Gradle/build ownership:** structure plugins, dependency groups, test
   suites, quality gates, cache/configuration settings, Paketo JVM/native image
   properties, and Docker image smoke tasks in Gradle. Remove duplicated
   service-local shell gate logic.
5. **Workspace operations:** retain minimal Compose orchestration, strengthen
   digest-reference validation, and keep observability/release checks honest.

## Acceptance

- New focused tests cover every changed behavior before implementation code is
  considered complete.
- Service quality gate, provider quality/contract/build checks, workspace
  validation, OpenAPI validation, shell syntax checks, and available Compose
  checks pass. Docker-dependent checks are reported separately when the daemon
  is unavailable.
- No placeholders, stale provider schemas, duplicated build authority, or
  unresolved contradictions remain in the changed scope.
