#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yml"
RELEASE_DIR="${RELEASE_DIR:-$PROJECT_ROOT/.releases}"
MODE="all"
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
case "${1:-}" in "") ;; --api-only) MODE=api ;; --web-only) MODE=web ;; *) die "usage: $0 [--api-only|--web-only]" ;; esac
[[ -r "$ENV_FILE" ]] || die "environment file not found: $ENV_FILE"
env_mode="$(stat -c '%a' "$ENV_FILE")"
[[ "$env_mode" == 600 || "$env_mode" == 400 ]] || die "$ENV_FILE must have mode 0600 or 0400 (currently $env_mode)"
REQUESTED_TAG="${TAG:-}"
# shellcheck source=/dev/null
source "$ENV_FILE"
TAG="${REQUESTED_TAG:-${TAG:-}}"
[[ -n "$TAG" && "$TAG" != latest && "$TAG" =~ ^sha-[0-9A-Za-z._-]+$ ]] || die "TAG must be an immutable sha-* release tag; latest is prohibited"
BACKEND_IMAGE="${BACKEND_IMAGE%:*}:$TAG"
FRONTEND_IMAGE="${FRONTEND_IMAGE%:*}:$TAG"
export TAG BACKEND_IMAGE FRONTEND_IMAGE
required=(DOMAIN API_DOMAIN GRAFANA_DOMAIN BACKEND_IMAGE FRONTEND_IMAGE SUPABASE_CONNECTION_STRING REDIS_PASSWORD JWT_KEY ENCRYPTION_KEY INTERNAL_API_KEY EMAIL_SMTP_HOST EMAIL_SMTP_USERNAME EMAIL_SMTP_PASSWORD GRAFANA_ADMIN_PASSWORD STORAGE_WEBSITE_S3_ENDPOINT STORAGE_WEBSITE_S3_ACCESS_KEY_ID STORAGE_WEBSITE_S3_SECRET_ACCESS_KEY STORAGE_WEBSITE_BUCKET STORAGE_WEBSITE_PUBLIC_BASE_URL)
for name in "${required[@]}"; do
  value="${!name:-}"
  [[ -n "$value" && "$value" != *CHANGE_ME* && "$value" != *CHANGE-ME* ]] || die "$name is missing or contains a placeholder"
done
[[ ${#INTERNAL_API_KEY} -ge 32 ]] || die "INTERNAL_API_KEY must be at least 32 characters"
command -v docker >/dev/null 2>&1 || die "docker is required"
docker info >/dev/null 2>&1 || die "Docker daemon is unavailable"
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is required"
docker network inspect traefik-public >/dev/null 2>&1 || die "external network traefik-public does not exist"
compose=(docker compose --env-file "$ENV_FILE" --project-directory "$PROJECT_ROOT" -f "$COMPOSE_FILE")
"${compose[@]}" config --quiet
mkdir -p "$RELEASE_DIR"
umask 077
current_api="$("${compose[@]}" ps -q claudygod-api 2>/dev/null | head -n1)"
current_web="$("${compose[@]}" ps -q claudygod-web 2>/dev/null | head -n1)"
{
  printf 'PREVIOUS_API_IMAGE=%q\n' "$(if [[ -n "$current_api" ]]; then docker inspect --format '{{.Config.Image}}' "$current_api"; fi)"
  printf 'PREVIOUS_WEB_IMAGE=%q\n' "$(if [[ -n "$current_web" ]]; then docker inspect --format '{{.Config.Image}}' "$current_web"; fi)"
  printf 'CAPTURED_AT=%q\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$RELEASE_DIR/previous.env"
case "$MODE" in api) services=(claudygod-api migrate) ;; web) services=(claudygod-web) ;; all) services=(redis claudygod-api migrate claudygod-web grafana) ;; esac
info "Pulling immutable release $TAG..."
"${compose[@]}" pull "${services[@]}"
if [[ "$MODE" != web ]]; then
  info "Applying forward-compatible database migrations..."
  "${compose[@]}" run --rm migrate
fi
case "$MODE" in api) "${compose[@]}" up -d --no-deps claudygod-api ;; web) "${compose[@]}" up -d --no-deps claudygod-web ;; all) "${compose[@]}" up -d --remove-orphans redis claudygod-api claudygod-web grafana ;; esac
if ! "$SCRIPT_DIR/health-check.sh" --wait; then
  info "Readiness failed; restoring the previous application images..."
  "$SCRIPT_DIR/rollback.sh" --non-interactive || true
  die "deployment failed; database migrations are not automatically reversed"
fi
printf '{"tag":"%s","mode":"%s","deployedAt":"%s"}\n' "$TAG" "$MODE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$RELEASE_DIR/current.json"
docker image prune -f --filter "until=168h" >/dev/null
info "Release $TAG deployed and verified."
"${compose[@]}" ps
