# ADR 0005: Filters, Observations, and AOP Boundaries

- Status: Accepted
- Date: 2026-09-16

## Context

Some behavior belongs at the HTTP boundary, while other behavior belongs at a
use-case or provider boundary. Applying one mechanism everywhere would make
ordering and failure semantics unclear.

## Decision

- Use `InboundRateLimitFilter` for admission control on `GET /backend-service`.
  It runs before controller binding and can return `429` or `503` without
  entering the application use case.
- Use Resilience4j decorators/annotations at provider operations where retry,
  circuit-breaker, rate-limit, and bulkhead ordering is meaningful.
- Use Micrometer `@Observed` on use cases for stable operation metrics/traces.
- Keep idempotency and verification conflict logic in application services and
  PostgreSQL, not in AOP advice.

## Consequences

The request filter is explicit and easy to test as a servlet boundary. AOP is
limited to cross-cutting telemetry/resilience and does not hide business state
transitions. The trade-off is that the same operation may have both filter and
method-level tests, which is intentional because they protect different
boundaries.
