# Local Observability Compose Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add an optional Prometheus, Grafana, Tempo, Loki, and Alloy profile and document Docker resource sizing.

**Architecture:** Prometheus scrapes Actuator. Spring Boot Micrometer observations export traces over OTLP to Alloy, which forwards them to Tempo. Alloy reads Docker logs through a read-only socket and sends them to Loki; Grafana is provisioned with all three datasources.

**Tech Stack:** Docker Compose, Spring Boot 4.1.1, Micrometer, OpenTelemetry, Grafana Alloy, Prometheus, Tempo, Loki, Grafana.

## Global Constraints

- Preserve existing API, persistence, provider, and core Compose behavior.
- Keep observability opt-in through the `observability` Compose profile.
- Do not mount a Docker socket into backend or provider containers.
- Keep release image inputs immutable and local development tags configurable.
- Use Docker Desktop's default socket; Colima requires only its documented VM override.

---

### Task 1: Add observability configuration assets

**Files:**
- Create: `observability/prometheus/prometheus.yml`
- Create: `observability/tempo/tempo.yaml`
- Create: `observability/loki/loki-config.yaml`
- Create: `observability/alloy/config.alloy`
- Create: `observability/grafana/provisioning/datasources/datasources.yml`

- [ ] Write configuration files with service-DNS targets, OTLP receivers, local development storage, and Grafana datasources.
- [ ] Validate each file through the Compose profile smoke startup.

### Task 2: Add the Compose observability profile

**Files:**
- Create: `compose.observability.yaml`
- Modify: `compose.yaml`
- Modify: `compose.distributed.yaml`
- Modify: `.env.example`

- [ ] Add profile services, health checks, ports, volumes, and dependencies.
- [ ] Override backend OTLP tracing configuration only when the profile file is supplied.
- [ ] Add image variables and local defaults.
- [ ] Render single-node and distributed profile configurations.

### Task 3: Enable Spring Boot OTLP tracing

**Files:**
- Modify: `company-check-service/gradle/libs.versions.toml`
- Modify: `company-check-service/build.gradle.kts`
- Modify: `company-check-service/src/main/resources/application.yml`
- Modify: `company-check-service/src/test/java/com/incode/verification/configuration/ObservabilityConfigurationTest.java`

- [ ] Add `spring-boot-starter-opentelemetry` using the existing Spring Boot BOM.
- [ ] Configure disabled-safe defaults and profile-provided OTLP endpoint/sampling.
- [ ] Extend the configuration test for trace sampling and endpoint properties.
- [ ] Refresh dependency locks and verification metadata with Gradle.

### Task 4: Fix performance topology/default precedence

**Files:**
- Modify: `company-check-service/performance/run.sh`
- Modify: `company-check-service/performance/scenarios.env`
- Modify: `README.md`

- [ ] Load scenario defaults without overwriting explicitly supplied environment variables.
- [ ] Scale distributed performance runs to two backends by default.
- [ ] Document observability startup, URLs, resource sizing, and Docker Desktop/Colima settings.

### Task 5: Verify

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/component-quality.yml`

- [ ] Pin CI quality jobs to Java 25.
- [ ] Run service `fastCheck`, `integrationTest`, `openApiValidate`, and provider `bun run quality`.
- [ ] Run Compose config checks.
- [ ] Start the observability profile and verify health, Prometheus targets, Tempo traces, Loki logs, and Grafana datasource provisioning.
- [ ] Run a short Locust smoke against single-node and distributed profiles.
