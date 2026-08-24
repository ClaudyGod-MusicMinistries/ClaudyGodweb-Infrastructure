#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
MAINTENANCE_FILE="$PROJECT_ROOT/docker/docker-compose.maintenance.yml"
RELEASE_DIR="${RELEASE_DIR:-$PROJECT_ROOT/.releases}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "$1 is required"; }

load_env() {
  local enforce_permissions="${1:-true}" mode requested_tag="${TAG:-}" invalid_line
  [[ -r "$ENV_FILE" ]] || die "environment file not found: $ENV_FILE"
  if [[ "$enforce_permissions" == true ]]; then
    mode="$(stat -c '%a' "$ENV_FILE")"
    [[ "$mode" == 600 || "$mode" == 400 ]] || die "$ENV_FILE must have mode 0600 or 0400 (currently $mode)"
  fi
  invalid_line="$(grep -nE "^[A-Za-z_][A-Za-z0-9_]*=[^\"']*[[:space:]]" "$ENV_FILE" | head -n1 || true)"
  [[ -z "$invalid_line" ]] || die "unquoted whitespace in $ENV_FILE: $invalid_line"
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  [[ -z "$requested_tag" ]] || TAG="$requested_tag"
}

require_values() {
  local name value
  for name in "$@"; do
    value="${!name:-}"
    [[ -n "$value" && "$value" != *CHANGE_ME* && "$value" != *CHANGE-ME* && "$value" != *REPLACE_ME* ]] || die "$name is missing or contains a placeholder"
  done
}

require_docker() {
  require_command docker
  docker info >/dev/null 2>&1 || die "Docker daemon is unavailable"
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is required"
}

compose() {
  docker compose --env-file "$ENV_FILE" --project-directory "$PROJECT_ROOT" -f "$COMPOSE_FILE" "$@"
}

compose_maintenance() {
  docker compose --env-file "$ENV_FILE" --project-directory "$PROJECT_ROOT" -f "$COMPOSE_FILE" -f "$MAINTENANCE_FILE" "$@"
}

validate_release_env() {
  require_values DOMAIN API_DOMAIN GRAFANA_DOMAIN TAG BACKEND_IMAGE FRONTEND_IMAGE \
    SUPABASE_CONNECTION_STRING REDIS_PASSWORD JWT_KEY ENCRYPTION_KEY INTERNAL_API_KEY \
    EMAIL_SMTP_HOST EMAIL_SMTP_USERNAME EMAIL_SMTP_PASSWORD GRAFANA_ADMIN_PASSWORD \
    STORAGE_WEBSITE_S3_ENDPOINT STORAGE_WEBSITE_S3_ACCESS_KEY_ID \
    STORAGE_WEBSITE_S3_SECRET_ACCESS_KEY STORAGE_WEBSITE_BUCKET \
    STORAGE_WEBSITE_PUBLIC_BASE_URL BACKUP_AGE_RECIPIENT
  [[ "$TAG" =~ ^sha-[0-9A-Za-z._-]+$ ]] || die "TAG must be an immutable sha-* release tag"
  [[ ${#INTERNAL_API_KEY} -ge 32 ]] || die "INTERNAL_API_KEY must be at least 32 characters"
}
