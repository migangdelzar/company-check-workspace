# Contract and Business E2E Coverage Implementation Plan

> Execute this plan in the workspace root. Preserve unrelated root and service
> changes already present in the working tree.

## Goal

Make the backend contract suite execute real Spring MVC boundary tests and make
the reusable Compose E2E action prove one successful verification is completed
and persisted.

## Scope and constraints

- Add tests only for existing HTTP behavior; do not change production API,
  persistence, provider, or image contracts.
- Keep contract tests network-free by using the existing Spring MVC test
  infrastructure and Mockito ports.
- Keep the Compose E2E scenario single-node and use the existing deterministic
  `CJQUNXGW` provider fixture.
- Stage and commit only files created or modified for this plan.

## Task 1: Add executable backend contract tests

File: `company-check-service/src/contractTest/java/com/incode/BackendApiContractTest.java`

1. Confirm the baseline `contractTest` is currently `NO-SOURCE`.
2. Add a Spring MVC contract test class covering:
   - `GET /backend-service` delegates the UUID and query to
     `StartVerificationUseCase`, returns `200`, the documented JSON fields,
     and `Cache-Control: no-store`.
   - `GET /verifications/{verificationId}` delegates the UUID to
     `GetVerificationUseCase`, returns `200`, and `Cache-Control: no-store`.
   - Invalid blank query returns `400` with the existing
     `application/problem+json` and `Invalid request` shape.
3. Use `@WebMvcTest` with the two controllers and `@MockitoBean` ports, matching
   the repository's Spring Boot 4 test APIs. Include representative
   `VerificationResult` values so JSON serialization is checked at the
   boundary.
4. Run the contract suite and the service quality gate. The suite must report
   executed tests, not `NO-SOURCE`.

## Task 2: Add business assertions to the reusable Compose E2E action

File: `.github/actions/compose-e2e/action.yml`

1. Keep the existing `docker compose up`, health polling, and cleanup trap.
2. After the backend is healthy, create a unique UUID and call
   `/backend-service?verificationId=<uuid>&query=CJQUNXGW`.
3. Assert with `jq` that the response is successful, `verificationId` matches,
   `status` is `COMPLETED`, `provider` is `FREE`, and `company.cin` is
   `CJQUNXGW`.
4. Fetch `/verifications/<uuid>` and assert the same ID, completed status, and
   persisted company CIN. A curl or JSON assertion failure must fail the action.
5. Do not add a second distributed-topology business flow in this change.

## Task 3: Harden query canonicalization at the input boundary

Files:

- `company-check-service/src/main/java/com/incode/verification/domain/query/NormalizedQuery.java`
- `company-check-service/src/test/java/com/incode/verification/domain/query/NormalizedQuerySecurityTest.java`

1. Canonicalize raw query text with Unicode NFKC, Unicode-aware whitespace
   stripping, and root-locale uppercasing before it enters domain identity,
   persistence, coordination, or provider lookup.
2. Reject ISO control and Unicode format characters, including line breaks,
   NUL, and zero-width/bidi-style formatting characters.
3. Keep values unencoded in domain and database state. SQL uses named
   parameters, JSON serialization handles JSON output encoding, and the
   provider HTTP client owns URI-template variable encoding for its request
   context.
4. Cover compatibility-character canonicalization, Unicode whitespace, and
   unsafe-character rejection with unit tests.

## Task 4: Run bounded stress testing in GitHub Actions

Files:

- `.github/workflows/performance.yml`
- `.github/workflows/e2e.yml`
- `company-check-service/performance/run.sh`
- `company-check-service/performance/locustfile.py`
- `docs/architecture/testing.md`

1. Expose a manual and reusable performance workflow accepting immutable image
   references, topology, user count, spawn rate, and bounded duration.
2. Run the workflow with strict HTTP success semantics and upload Locust HTML
   and CSV diagnostics even when the job fails.
3. Wire the reusable stress job after the existing workspace E2E job so the
   image-based E2E pipeline also exercises load behavior.
4. Make the runner safe under `set -u` for both single and distributed
   topologies and fail when aggregate failure rate or p95 latency exceeds the
   configured thresholds.

## Verification sequence

Run in order:

1. `./gradlew contractTest --no-parallel --max-workers=1`
2. `./gradlew fastCheck --no-parallel --max-workers=1`
3. `./gradlew integrationTest --no-parallel --max-workers=1` with the local
   Testcontainers Docker host override when required.
4. Provider quality and contract tests.
5. OpenAPI validation.
6. Start the local Compose stack with the current local images and execute the
   same business assertions used by the action, then tear down only that
   Compose project.
7. Inspect the final diff and commit only the implementation files above plus
   this plan.

## Completion criteria

- Contract tests execute and pass.
- Compose E2E action contains and locally passes the successful business flow.
- Query input is canonicalized consistently and unsafe control/format
  characters are rejected.
- Existing fast, integration, provider, and OpenAPI gates remain green.
- No unrelated concurrent changes are staged or discarded.
