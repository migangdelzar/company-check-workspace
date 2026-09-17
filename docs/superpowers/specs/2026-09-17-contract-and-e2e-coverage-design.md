# Contract and Business E2E Coverage Design

| Field | Detail |
|---|---|
| Scope | Workspace service contract tests and Compose business-flow E2E |
| Date | 2026-09-17 |
| Status | Approved design |

## Goal

Make the CI quality gates prove both HTTP contract behavior and one successful
end-to-end verification flow. Preserve the current service/provider contracts,
Compose topology, immutable image inputs, and existing Testcontainers IT suite.

## Current gap

- `contractTest` has no Java sources, so Gradle reports `NO-SOURCE`.
- `e2eTest` has no Java sources, so Gradle reports `NO-SOURCE`.
- The reusable Compose E2E action only waits for `backend running healthy`.
- No CI assertion currently starts a verification and reads it back.

## Chosen design

### 1. Backend contract suite

Create `company-check-service/src/contractTest/java/com/incode/BackendApiContractTest.java`.

Use the existing Spring MVC test stack and injected Mockito beans. Keep this
suite network-free and focused on the externally visible HTTP contract:

- `GET /backend-service` accepts `verificationId` and `query`, delegates to the
  start use case, returns HTTP 200, returns JSON company/result fields, and
  sends `Cache-Control: no-store`.
- `GET /verifications/{verificationId}` delegates to the retrieval use case,
  returns HTTP 200, and sends `Cache-Control: no-store`.
- Invalid request input returns the existing problem response shape and HTTP
  400.

The existing `openApiValidate` task remains the schema/document lint gate;
these tests prove that the running Spring MVC boundary implements the intended
method, path, status, headers, and payload shape.

### 2. Compose business E2E

Extend `.github/actions/compose-e2e/action.yml` after the existing health wait.
Use the already published backend port and a known deterministic provider
fixture (`CJQUNXGW`). The shell flow will:

1. Generate a unique verification UUID.
2. `GET /backend-service` with the UUID and fixture query.
3. Assert HTTP 200 and a completed result from the FREE provider.
4. Assert the returned company CIN is `CJQUNXGW`.
5. `GET /verifications/{id}`.
6. Assert the stored result remains completed and contains the same CIN.

Use `curl` plus `jq`, both available on the GitHub-hosted Ubuntu runner. Keep
the existing `docker compose down` trap so failed runs still clean up.

## Alternatives considered

### A. Add only Java contract/E2E test sources

Rejected. The Java `e2eTest` suite does not currently have a provider simulator
or Compose network fixture, so it would either duplicate unit tests or require
new test infrastructure and dependencies.

### B. Add only shell assertions to Compose E2E

Rejected. This would validate the deployed stack but leave the Gradle contract
suite permanently `NO-SOURCE`, weakening the service quality gate.

### C. Add single-node and distributed business E2E in this change

Deferred. The distributed overlay intentionally removes the host backend port,
so it needs a separate internal-network client flow and replica-specific
assertions. This change closes the immediate health-only gap with the existing
single-node CI path.

## Success criteria

- `./gradlew contractTest` executes real tests with zero failures.
- `./gradlew e2eTest` remains explicit about whether it has no Java sources;
  Compose E2E carries the deployed business-flow assertion.
- The reusable Compose action fails when the API cannot complete and persist a
  known verification, even if health checks pass.
- Existing `fastCheck`, `check`, IT, provider, and OpenAPI gates remain green.
- No production behavior, database schema, provider fixture, or image contract
  changes are introduced.

## Out of scope

- Release, promotion, or package publishing workflows.
- Distributed topology business testing.
- New runtime or test dependencies.
- Changes to the current API or provider response contracts.
