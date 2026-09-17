# ADR 0006: Virtual Threads with Bounded Resources

- Status: Accepted
- Date: 2026-09-16

## Context

The service performs blocking JDBC and provider HTTP calls. Virtual threads can
improve concurrency for these waits, but they do not create more database
connections, provider quota, CPU, or memory.

## Decision

Enable Spring Boot virtual threads for request and scheduling execution. Keep
scarce resources bounded independently: Hikari connections, provider HTTP pool,
Resilience4j bulkheads/rate limits, Redis pool, and test worker forks. Use
structured lifetimes through Spring-managed tasks and try-with-resources rather
than introducing an application-wide custom structured-concurrency framework.

## Consequences

More blocked requests can wait without occupying platform threads, while the
resource pools remain the real back-pressure controls. Pinning or CPU-heavy work
must still be bounded. Spring manages the ordinary request/task lifecycle; an
explicit `StructuredTaskScope` is not needed for the current sequential
verification flow.
