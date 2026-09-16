#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/compose-command.sh up -d
