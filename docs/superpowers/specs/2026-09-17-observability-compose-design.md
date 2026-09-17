# Local Observability Compose Design

## Goal

Add an optional local observability profile for the Company Check workspace and
document resource sizing for one through four backend replicas.

## Decision

Keep the existing API, database, provider, and Locust Compose paths unchanged.
Add `compose.observability.yaml`, activated explicitly with the `observability`
profile. The profile runs Prometheus, Grafana, Tempo, Loki, and Grafana Alloy.

Prometheus scrapes the backend's existing `/actuator/prometheus` endpoint.
Spring Boot's OpenTelemetry starter bridges Micrometer observations to Alloy;
Alloy forwards traces to Tempo. Alloy tails Docker container logs through a
read-only Docker socket mount and forwards them to Loki. Only Alloy receives a
Docker socket; application containers do not.

## Runtime topology

```text
backend --OTLP/gRPC--> alloy --OTLP/gRPC--> tempo
backend --stdout--> Docker daemon --read-only socket--> alloy --> loki
prometheus --HTTP scrape--> backend /actuator/prometheus
grafana --> prometheus, tempo, loki
```

The profile exposes Grafana on 3000, Prometheus on 9090, Tempo on 3200, Loki on
3100, and Alloy's UI on 12345. The telemetry services use local filesystem
volumes and are for development and smoke testing, not production deployment.

## Resource policy

The README will document the following starting recommendations for Docker
Desktop or Colima: 4 vCPUs and 6 GiB for one or two replicas with the optional
observability profile; 8 vCPUs and 12 GiB for three or four replicas. The
figures include PostgreSQL, Redis, both provider simulators, Locust, and the
observability services, with headroom for JVM native memory and filesystem
cache. Locust-heavy tests may need additional resources.

## Configuration and safety

- Image tags are configurable through `.env.example`; release validation uses
  immutable digests.
- Loki uses single-binary local filesystem storage and disables authentication,
  which is acceptable only because the profile is local development.
- Alloy's Docker socket mount is read-only and restricted to the observability
  profile.
- Health checks use each component's documented HTTP readiness endpoint where
  the image provides one.
- Grafana datasource provisioning uses Compose service DNS names, never
  `localhost` between containers.

## Verification

- Compose config renders with and without the profile.
- Service unit, integration, and provider quality checks remain green.
- A profile smoke run verifies all observability health endpoints, Prometheus
  target health, a generated trace, and a log query in Loki.
- README commands document Docker Desktop and Colima startup/resource settings.

## References

- Spring Boot 4.1 tracing and OTLP: https://docs.spring.io/spring-boot/reference/actuator/tracing.html
- Spring Boot Prometheus endpoint: https://docs.spring.io/spring-boot/reference/actuator/metrics.html
- Grafana Alloy Docker log source: https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.docker/
- Grafana Tempo Docker/OTLP setup: https://grafana.com/docs/tempo/latest/set-up-for-tracing/instrument-send/set-up-collector/otel-collector/
- Grafana Loki OTLP ingestion: https://grafana.com/docs/loki/latest/send-data/otel/otel-collector-getting-started/
