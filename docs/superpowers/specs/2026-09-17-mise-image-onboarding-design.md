# Mise-Based JVM and Native Image Onboarding

## Scope

Make `mise` the primary local onboarding interface for service validation,
provider checks, image builds, Compose startup, and shutdown. Provide one
complete command for a JVM image setup and one for a native image setup while
preserving the existing Gradle/Paketo image contract.

## Design

Add two explicit tasks:

- `mise run setup-jvm` — build the provider image, build the JVM service image,
  start the single-node Compose stack, and wait for backend health.
- `mise run setup-native` — perform the same flow with
  `-PimageVariant=native -PnativeOptimization=b`.

Both tasks use the existing local image tags:
`company-check-provider:local` and `company-check-service:local`. They create
`.env` from `.env.example` only when `.env` is absent and never overwrite an
existing environment file. They require real digest-pinned Paketo builder/run
references in `company-check-service/gradle.properties`; they do not invent or
download an unapproved digest value.

Move shared setup/build/wait logic into a small repository script called by
both tasks. The script will:

1. Verify the requested variant and required tools.
2. Start Colima only when Docker is unavailable and Colima is installed.
3. Check the active Docker daemon memory before building.
4. Run locked provider installation and quality checks.
5. Build the provider image with the existing Dockerfile.
6. Build the service image through the existing Gradle `image` task.
7. Render/start the single-node Compose stack and wait for health.

Replace the stale `docker-cli-plugin-docker-compose` references in existing
`mise` tasks with the `docker-compose` executable installed by the pinned
`mise` tool. Fix service task paths to pass `-p company-check-service` and make
the provider task install locked dependencies before quality checks. Keep
existing task names as compatibility aliases where practical.

## Memory guidance

The documentation will state operational recommendations, not hard platform
requirements:

- JVM image build: 4 GiB Docker memory recommended; 2 GiB is a lower-bound
  development attempt and may fail from Gradle/Paketo overhead.
- Native image build: 12 GiB Docker memory recommended because the Paketo
  native-image build includes a GraalVM/native-image toolchain and native
  compilation.

The setup script will fail with the detected Docker memory and remediation when
the active daemon is below the variant recommendation. It will not stop or
reconfigure Docker Desktop or an already-running Colima VM automatically.

Paketo documents the Java Native Image Buildpack as providing the required
GraalVM/native-image build component; the repository-specific memory values are
local operational guidance rather than a Paketo hard minimum:

- <https://paketo.io/docs/reference/java-native-image-reference/>
- <https://paketo.io/docs/reference/java-reference/>

## Documentation updates

Update the root README, startup guide, testing/performance guidance, and the
service image contract so the recommended path is the two `mise` commands.
Keep manual Gradle commands as an advanced fallback and retain the immutable
image, native optimization, publishing, and smoke-test rules.

## Boundaries and non-goals

- No production Java, TypeScript, API, persistence, or provider behavior
  changes.
- No invented Paketo digests or mutable release image references.
- No automatic overwrite of `.env`, `gradle.properties`, Docker Desktop
  settings, or an active Colima configuration.
- Native and JVM image builds continue to use the existing Gradle/Paketo path;
  no second Dockerfile or parallel image implementation is introduced.

## Verification

- Test the `mise.toml` task definitions and setup script with shell syntax
  checks and dry-run/error-path checks for missing digests and low memory.
- Run `mise run validate` and `mise run provider` when their dependencies are
  available.
- Render single-node and distributed Compose configurations.
- Run the JVM setup command when approved Paketo digests and Docker memory are
  available; run native setup under the 12 GiB recommendation when available.
- Run Markdown link, Mermaid, and `git diff --check` validation.
