# ADR 0007: Gradle, Paketo, and Immutable Compose Inputs

- Status: Partially superseded by [ADR 0009](0009-paketo-auto-resolution.md)
- Date: 2026-09-16

## Context

Build, image, and workspace verification need one reproducible entry point.
Mutable image tags make local and CI results difficult to compare, while manual
Dockerfiles would duplicate Spring Boot runtime knowledge.

## Decision

Use Gradle Kotlin DSL with the included `build-logic` convention plugins for
service build logic, configuration/build caches, strict dependency verification, Spotless, Checkstyle,
Detekt, Error Prone, NullAway, JaCoCo, and OpenAPI validation. Use Spring Boot's
Paketo `bootBuildImage` integration for OCI images. Require builder, run, and
Compose image inputs to be digest-pinned for CI/release validation. Permit
local tags for development; the performance runner resolves local images to
their repository digests before starting its Compose stack. Use Compose
overlays for single-node and distributed topologies.

## Consequences

Build policy is centralized and testable. Paketo supplies a supported JVM image
layout and non-root runtime contract. Digest pinning improves repeatability but
requires approved image values in local/CI settings. Compose remains a
workspace integration tool, not a replacement for the service's Gradle tests.
