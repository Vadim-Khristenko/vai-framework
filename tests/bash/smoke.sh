#!/usr/bin/env bash
# Smoke test for bash companion
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/contrib/bash/vai.sh"

echo "bash smoke root=$ROOT"
vai version
ai list >/dev/null || true
cmd_docker_help >/dev/null || true
echo "bash smoke OK"
