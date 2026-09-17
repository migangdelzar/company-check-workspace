# Company Check Documentation

This documentation describes the decisions, architecture, runtime topologies,
and verification workflow for the Company Check workspace.

The backend is currently a conventional layered Spring Boot Modulith:
`config` composes the runtime, `controller` owns HTTP and scheduling
boundaries, `service` owns workflows, `repository` owns persistence and
coordination, `client` owns provider HTTP, `mapper` performs explicit
representation conversion, and `exception` owns error translation. The
Bun/Fastify provider simulator remains a separate deployable.

## Start here

- [Workspace README](../README.md) — setup, Compose profiles, tests, and Locust.
- [Architecture index](architecture/README.md) — system boundaries and runtime flows.
- [Runtime architecture](architecture/runtime-architecture.md) — build-to-runtime topology and observability components.
- [Resilience and fallback](architecture/resilience.md) — admission control, provider fallback, and bounded resource behavior.
- [Application startup](architecture/startup.md) — complete local startup and shutdown sequence.
- [ADR index](adr/README.md) — technology and design decisions.
- [Image contract](../company-check-service/docs/image-contract.md) — immutable image rules.

## Documentation rules

- ADRs record decisions and trade-offs; they do not prescribe implementation steps.
- Architecture documents describe the current system and may link to source/configuration.
- Mermaid diagrams are kept beside the explanation they support.
- When a decision changes, add a new ADR or mark the old ADR superseded; do not silently rewrite history.
- Superpowers specs and plans are process records. If they describe an older
  architecture, their status note takes precedence over obsolete package names.
