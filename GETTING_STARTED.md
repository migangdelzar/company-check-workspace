# Getting Started

Company Check is a verification platform made of a Spring Boot service, a
Bun-based provider simulator, and Docker Compose topologies. Everything about
running, validating, and tearing down the stack is exposed through
[mise](https://mise.jdx.dev) tasks, so you only need to install one tool.

This guide covers installing mise, preparing the workspace, and running the
stack end to end. It is the recommended entry point; the [README](README.md)
holds the full operational reference.

## Prerequisites

- macOS or Linux, about 8 GiB of free memory (4 GiB is the minimum for a JVM
  stack, 12 GiB is recommended for native image builds; see the memory table).
- Git.
- About 3 GiB of free disk for the tools, images, and build caches.
- No Docker installation is required: mise installs a pinned Docker CLI,
  Compose, and Colima runtime for you. If you already run Docker Desktop or a
  Colima VM, the setup uses your daemon as-is when it has enough memory.

## Install mise

mise is a single binary. Install it with Homebrew on macOS:

```sh
brew install mise
```

Or with the official installer on macOS/Linux:

```sh
curl https://mise.jdx.dev/install.sh | sh
```

Then activate mise in your shell (Bash):

```sh
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
```

or zsh:

```sh
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
```

Open a new terminal and verify:

```sh
mise --version
```

The workspace pins every tool (Java 25, Bun, Docker CLI, Compose, Colima) in
`mise.toml`. You never install them manually again.

## Prepare the workspace

Clone the repository and initialize both submodules (`company-check-service`
and `company-check-provider`):

```sh
git clone <repository-url> company-check-workspace
cd company-check-workspace
```

Trust the local mise configuration and install every pinned tool, including
the lazy-installed Colima runtime:

```sh
mise run install
```

`mise run install` also creates `.env` from `.env.example` the first time,
without overwriting an existing `.env`. Verify your environment:

```sh
mise run doctor
```

Every `mise run ...` command auto-installs any missing tool, so after `mise run install`
nothing else needs a manual setup step.

## Run the stack

Two complete setup commands exist: one for the JVM image and one for the
(native image) GraalVM path. Both build the provider and service images,
start the single-node stack, and wait for the health endpoint.

Recommended for most machines:

```sh
mise run setup-jvm
```

Native image builds take much longer and need a larger Docker allocation:

```sh
mise run setup-native
```

The setup uses an existing Docker daemon when it is reachable, otherwise it
starts Colima automatically with 4 GiB (JVM) or 11 GiB (native). It never
reconfigures Docker Desktop or an already-running Colima VM.

### Image-build memory

These are local operational recommendations, not hard minimums. The setup task
fails with the detected value and remediation when the active daemon is below
the gate.

| Image path | Setup gate | Guidance |
|---|---:|---|
| JVM | 4 GiB | 2 GiB is a constrained lower-bound attempt and may fail from Gradle/Paketo overhead. |
| Native | 11 GiB | 12 GiB recommended; native compilation adds a GraalVM/native-image toolchain. |

When Docker Desktop is below the gate, raise the allocation under Settings →
Resources. For Colima, the default profile is `emme`; recreate it with the
allocation you need:

```sh
colima stop emme
colima start emme --cpu 4 --memory 12
```

Override the profile name with `COLIMA_PROFILE` if your VM uses a different one.

## Verify it works

Check the backend health endpoint:

```sh
mise run health
```

Start a verification through the current API shape:

```sh
mise run smoke
```

## Daily commands

| Command | Purpose |
|---|---|
| `mise run install` | Init submodules, install pinned tools, create `.env` once. |
| `mise run trust` | Trust the local mise configuration. |
| `mise run doctor` | Verify tools, submodules, Docker daemon, and memory. |
| `mise run tools` | List installed tool versions. |
| `mise run current` | Show active tool versions for this project. |
| `mise run outdated` | Check pinned tools for newer versions. |
| `mise run setup-jvm` / `setup-native` | Full flow: build images + start single-node stack + wait for health. |
| `mise run start` | Start an already-built single-node stack. |
| `mise run start-distributed` | Start Redis-coordinated two-replica topology. |
| `mise run start-observability` | Start single-node plus Prometheus, Grafana, Tempo, Loki, and Alloy. |
| `mise run health` | Curl the backend `/actuator/health`. |
| `mise run smoke` | Run one verification through the API. |
| `mise run ps` / `logs` | Inspect the running stack. |
| `mise run validate` | Fast service unit/quality gate (offset check only, no containers). |
| `mise run service-full` | Complete service gate (Testcontainers included). |
| `mise run provider` | Provider formatting, type, lint, and test checks. |
| `mise run compose-check` | Render and validate all Compose overlays. |
| `mise run performance` | Run the bounded Locust workload. |
| `mise run stop` | Stop the single-node and distributed stacks (keeps volumes). |
| `mise run clean` | Stop everything, remove Compose volumes, and untag local images. |

## Next steps

- [Startup and profiles](docs/architecture/startup.md) — manual/advanced commands, observability, and shutdown.
- [Testing and performance](docs/architecture/testing.md) — the verification pipeline.
- [Architecture index](docs/architecture/README.md) — diagrams and design rationale.