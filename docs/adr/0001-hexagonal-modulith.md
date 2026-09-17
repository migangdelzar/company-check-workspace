# ADR 0001: Layered Modulith Boundaries

The filename is retained for link stability. The accepted implementation is
layered; the former hexagonal package tree appears only as rejected historical
context.

- Status: Accepted
- Date: 2026-09-16

## Context

Company Check has a compact verification workflow and several infrastructure
concerns: HTTP, PostgreSQL, Redis, provider simulators, scheduling, rate
limiting, and observability. The service was simplified from an over-factored
DDD/hexagonal package tree to make the current execution path easier to follow
without weakening its tested boundaries.

## Decision

Use one Spring Boot Modulith module organized as conventional layers:

- `controller` contains HTTP endpoints, API DTOs, inbound admission, and the
  expiration scheduler.
- `service` contains verification/provider workflows and `service/model` data.
- `repository` contains JDBC persistence, coordination, leases, cache, and
  rate-limit implementations, including `repository/coordination` and
  `repository/ratelimit`.
- `client` contains typed FREE/PREMIUM provider HTTP clients and wire DTOs.
- `mapper` contains explicit conversions between layer representations.
- `exception` contains application errors and HTTP error mapping.
- `config` composes profiles, infrastructure beans, properties, and runtime
  hints.
- `util` contains narrowly scoped utilities that do not own business workflow.

Spring Modulith and layered architecture tests protect the package boundaries.

## Consequences

Service models and workflows can be tested without PostgreSQL, Redis, or
provider HTTP. Controllers depend on services; services depend on repository
and client contracts; concrete infrastructure is wired in `config`. This adds
some explicit layer types but keeps dependencies visible and replaceable.

The previous hexagonal package tree was rejected as unnecessary indirection for
the current scope. A full microservice split remains out of scope because the
backend and deterministic provider simulator have different deployment roles,
but the backend has no need to split its small workflow into services.
