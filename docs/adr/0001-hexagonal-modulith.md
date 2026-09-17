# ADR 0001: Hexagonal Modulith Boundaries

- Status: Accepted
- Date: 2026-09-16

## Context

Company Check has a small domain but several infrastructure concerns: HTTP,
PostgreSQL, Redis, provider simulators, scheduling, rate limiting, and
observability. Directly coupling the domain to those technologies would make
single-node tests and distributed deployment harder to reason about.

## Decision

Use a Spring Boot application organized around hexagonal ports and adapters:

- `domain` contains verification state and business rules.
- `application` contains use cases and ports.
- `adapter/in` contains HTTP and scheduling entry points.
- `adapter/out` contains persistence, coordination, rate limiting, and providers.
- `configuration` composes the runtime profile and infrastructure beans.

Spring Modulith and architecture tests protect the package boundaries.

## Consequences

The domain can be tested without PostgreSQL, Redis, or provider HTTP. Adapters
require explicit wiring, which adds some classes and constructor parameters but
makes dependencies visible and replaceable.

Alternatives such as a traditional layered service or a full microservice split
were rejected: the former hides infrastructure coupling, while the latter adds
operational cost without an independent deployment boundary today.
