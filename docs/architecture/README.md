# Architecture

- [System overview](overview.md) — components, ownership, and runtime profiles.
- [Runtime architecture](runtime-architecture.md) — layers, build artifacts, single/distributed deployments, observability, and resource bounds.
- [Resilience and fallback](resilience.md) — filters, rate limiters, provider fallback, connection pools, caches, leases, and failure handling.
- [Request flow](request-flow.md) — start/retrieve behavior and failure boundaries.
- [Expiration flow](expiration-flow.md) — single-owner batch expiration with TTL locks.
- [Deployment topologies](deployment.md) — Compose single-node and distributed layouts.
- [Starting the application](startup.md) — prerequisites, image builds, startup, and shutdown.
- [Testing and performance](testing.md) — Gradle, Testcontainers, Compose, and Locust.

The diagrams describe the current implementation. Source code and configuration
remain authoritative when an implementation changes before this documentation is
updated.

The backend currently uses a conventional layered module: `config` wires the
runtime, `controller` owns HTTP/scheduling boundaries, `service` owns workflows,
`repository` owns state/coordination, `client` owns provider HTTP, `mapper`
owns explicit conversions, `exception` owns error translation, and `util` is
limited to small framework-free utilities.
