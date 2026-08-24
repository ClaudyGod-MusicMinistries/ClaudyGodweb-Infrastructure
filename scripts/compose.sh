#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib/common.sh
# shellcheck disable=SC1091 -- resolved relative to this script at runtime
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
load_env true
require_docker
case "${1:-}" in
  maintenance-on)
    compose_maintenance rm -sf maintenance >/dev/null 2>&1 || true
    compose_maintenance up -d maintenance
    ;;
  maintenance-off)
    compose_maintenance rm -sf maintenance >/dev/null 2>&1 || true
    compose up -d --remove-orphans
    ;;
  *) compose "$@" ;;
esac
