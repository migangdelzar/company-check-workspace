# Architecture

- [System overview](overview.md) — components, ownership, and runtime profiles.
- [Request flow](request-flow.md) — start/retrieve behavior and failure boundaries.
- [Expiration flow](expiration-flow.md) — single-owner batch expiration with TTL locks.
- [Deployment topologies](deployment.md) — Compose single-node and distributed layouts.
- [Testing and performance](testing.md) — Gradle, Testcontainers, Compose, and Locust.

The diagrams describe the current implementation. Source code and configuration
remain authoritative when an implementation changes before this documentation is
updated.
