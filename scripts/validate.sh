#!/usr/bin/env bash
set -euo pipefail
production=false
validation_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == --production ]]; then
  production=true
else
  ENV_FILE="${ENV_FILE:-$(dirname "$validation_script_dir")/.env.example}"
fi
# The shared library is resolved relative to this script at runtime.
# shellcheck source=lib/common.sh
# shellcheck disable=SC1091
source "$validation_script_dir/lib/common.sh"
pass() { printf 'OK: %s\n' "$*"; }

load_env "$production"
if $production; then validate_release_env; pass "production environment"; fi
require_docker
compose config --quiet
compose_maintenance config --quiet
pass "Compose model and maintenance overlay"

for script in "$validation_script_dir"/*.sh "$validation_script_dir"/lib/*.sh; do bash -n "$script"; done
pass "shell syntax"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$validation_script_dir"/*.sh "$validation_script_dir"/lib/*.sh
  pass "ShellCheck"
else
  die "ShellCheck is required"
fi
