#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env.example}"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
MAINTENANCE_FILE="$PROJECT_ROOT/docker/docker-compose.maintenance.yml"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
pass() { printf 'OK: %s\n' "$*"; }

command -v docker >/dev/null 2>&1 || fail "docker is required"
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is required"
[[ -r "$ENV_FILE" ]] || fail "environment file is not readable: $ENV_FILE"

docker compose \
  --env-file "$ENV_FILE" \
  --project-directory "$PROJECT_ROOT" \
  -f "$COMPOSE_FILE" \
  config --quiet
pass "Docker Compose configuration"

docker compose \
  --env-file "$ENV_FILE" \
  --project-directory "$PROJECT_ROOT" \
  -f "$COMPOSE_FILE" -f "$MAINTENANCE_FILE" \
  config --quiet
pass "maintenance overlay"

for script in "$PROJECT_ROOT"/scripts/*.sh; do
  bash -n "$script"
done
pass "shell syntax"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$PROJECT_ROOT"/scripts/*.sh
  pass "ShellCheck"
else
  printf 'SKIP: ShellCheck is not installed\n'
fi

if grep -nE '^[[:space:]]*container_name:' "$COMPOSE_FILE" "$MAINTENANCE_FILE"; then
  fail "fixed container_name entries are prohibited"
fi
pass "scalable service naming"

if grep -nE 'image:.*:latest|TAG=latest' "$COMPOSE_FILE" "$PROJECT_ROOT/.env.example"; then
  fail "mutable latest releases are prohibited"
fi
pass "immutable production defaults"

grep -q 'Host(`\${DOMAIN}`)' "$MAINTENANCE_FILE" || fail "maintenance router must be hostname-scoped"
pass "maintenance routing scope"

if git -C "$PROJECT_ROOT" grep -nE \
  '(BEGIN (RSA|OPENSSH|EC|AGE) PRIVATE KEY|AGE-SECRET-KEY-|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk_live_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})' -- .; then
  fail "potential credential material detected"
fi
pass "basic secret scan"
