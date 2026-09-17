# ADR 0008: Explicit Testcontainers Docker Context

- Status: Accepted
- Date: 2026-09-16

## Context

Docker CLI contexts are not consistently consumed by the Java Docker client.
Colima and other VM-backed runtimes also expose a host socket path that the
Docker daemon cannot mount from inside its VM.

## Decision

The Gradle test convention accepts `testcontainersDockerHost` or `DOCKER_HOST`
and forwards it to every test worker. It also accepts
`testcontainersDockerSocketOverride` or
`TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE` and forwards the VM-visible socket path.
For Colima, the expected override is `/var/run/docker.sock`.

## Consequences

CI can provide the endpoint through environment variables without machine paths
in the repository. Local users can select any Docker context explicitly. Ryuk
cleanup remains enabled; only its socket path is adapted.
