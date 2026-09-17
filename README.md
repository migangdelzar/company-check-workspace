# Company Check Workspace

This repository contains the two independent project repositories as Git
submodules:

- `company-check-service/` — Spring Boot service and Gradle build logic.
- `company-check-provider/` — Bun/Fastify provider simulator.

The parent owns only workspace configuration and Compose wiring. There are no
parent shell helper scripts. Use `mise` for the short workspace entry point and
Gradle for service-owned verification.

## Common commands

```sh
# Fast service feedback: formatting, static analysis, unit tests and coverage
mise run validate

# Full service gate, including integration and contract checks
company-check-service/gradlew -p company-check-service qualityGate

# Validate the service OpenAPI contract
company-check-service/gradlew -p company-check-service openApiValidate

# Run the service-owned Locust workload through Gradle
mise run performance

# Provider checks
(cd company-check-provider && bun run quality)
```

## Compose

Copy `.env.example` to `.env`, replace the example image digests with approved
immutable references, then run:

```sh
docker compose up -d
docker compose ps
docker compose down
```

Compose definitions and GitHub Actions are kept in the parent; service tests,
the `performance/` Locust workload, and build implementation belong to the
service submodule.
