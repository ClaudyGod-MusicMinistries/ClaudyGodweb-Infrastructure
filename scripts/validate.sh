#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env.example}"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"

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

if git -C "$PROJECT_ROOT" grep -nE \
  '(BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|ghp_[A-Za-z0-9]{30,}|sk_live_[A-Za-z0-9]{20,})' -- .; then
  fail "potential credential material detected"
fi
pass "basic secret scan"
