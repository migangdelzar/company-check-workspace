#!/usr/bin/env bash
set -euo pipefail
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test -f observability/prometheus/prometheus.yml
test -f observability/mimir/config.yml
test -f observability/loki/config.yml
test -f observability/tempo/config.yml
test -f observability/grafana/provisioning/datasources/datasources.yml
test -f observability/grafana/dashboards/company-check.json
rg -q 'profiles: [observability]' compose.yaml
rg -q 'remote_write:' observability/prometheus/prometheus.yml
rg -q 'labeldrop' observability/prometheus/prometheus.yml
