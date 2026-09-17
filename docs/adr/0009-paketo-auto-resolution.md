# ADR 0009: Auto-Resolved Paketo Builder with Immutable Compose Inputs

- Status: Accepted
- Date: 2026-09-17
- Supersedes: The Paketo image clause of [ADR 0007](0007-gradle-paketo-and-immutable-compose.md)

## Context

ADR 0007 required digest-pinned Paketo builder and run images before any image
task could run. Spring Boot's `bootBuildImage` already auto-resolves a
well-known trusted builder and its embedded run image, and it auto-detects the
project Java version from `targetCompatibility`. Requiring and validating
external Paketo references duplicated plugin behavior, forced manual
`-PpaketoBuilderImage`/`-PpaketoRunImage` arguments in local builds and CI, and
the one-to-one `image` wrapper task added plumbing without value.

## Decision

`bootBuildImage` is the single Paketo entry point and resolves its builder
(`paketobuildpacks/builder-noble-java-tiny:latest`) and run image
automatically. The local `image` alias task is removed. The package convention
keeps only the property-driven tweaks Spring Boot does not provide by default:

- `imageName` default `company-check-service:<version>` (no registry prefix)
- `imageVariant` jvm/native switch with the JVM-specific AOT and
  `Spring-Boot-Native-Processed` handling
- `publishImage`, `paketoPullPolicy`, `cleanPaketoCache`, and stable
  `paketoCacheVolumePrefix` cache volumes
- OCI image labels and JVM head-room environment

The immutable Compose image-input requirement stays: `composeDigestCheck`
continues to require digest-pinned references for the service, provider,
PostgreSQL, Redis, and Locust images.

## Consequences

Local and CI image builds need no Paketo arguments; the builder tag is a
floating reference, so results can shift as Paketo publishes new releases. All
service-oriented image controls remain property-driven and Gradle-owned.
Compose supply-chain immutability is preserved.