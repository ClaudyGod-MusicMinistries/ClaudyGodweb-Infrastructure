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
  info "SKIP: ShellCheck is not installed"
fi

if grep -nE '^[[:space:]]*container_name:' "$COMPOSE_FILE" "$MAINTENANCE_FILE"; then die "fixed container_name entries are prohibited"; fi
if grep -nE 'image:.*:latest|TAG=latest' "$COMPOSE_FILE" "$PROJECT_ROOT/.env.example"; then die "mutable latest releases are prohibited"; fi
# ${DOMAIN} must remain literal in the Compose policy check.
# shellcheck disable=SC2016
grep -q 'Host(`\${DOMAIN}`)' "$MAINTENANCE_FILE" || die "maintenance router must be hostname-scoped"
pass "infrastructure policies"

if git -C "$PROJECT_ROOT" grep -nE '(BEGIN (RSA|OPENSSH|EC|AGE) PRIVATE KEY|AGE-SECRET-KEY-|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk_live_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})' -- .; then
  die "potential credential material detected"
fi
pass "basic secret scan"
