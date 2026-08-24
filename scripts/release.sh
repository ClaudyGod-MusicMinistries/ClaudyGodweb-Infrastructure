#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

health() {
  local attempts=1 api web attempt
  [[ "${1:-}" != --wait ]] || attempts=24
  for ((attempt=1; attempt<=attempts; attempt++)); do
    api="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://${API_DOMAIN}/healthz" 2>/dev/null)" || api=000
    web="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://${DOMAIN}/" 2>/dev/null)" || web=000
    if [[ "$api" == 200 && "$web" =~ ^(200|301|302)$ ]]; then
      info "Healthy: API=$api web=$web"
      return 0
    fi
    printf 'Not ready (%d/%d): API=%s web=%s\n' "$attempt" "$attempts" "$api" "$web" >&2
    (( attempt == attempts )) || sleep 5
  done
  return 1
}

rollback() {
  local non_interactive="${1:-}" answer state_file="$RELEASE_DIR/previous.env"
  [[ -r "$state_file" ]] || die "rollback state is missing: $state_file"
  # shellcheck source=/dev/null
  source "$state_file"
  require_values PREVIOUS_API_IMAGE PREVIOUS_WEB_IMAGE
  if [[ "$non_interactive" != --non-interactive ]]; then
    printf 'Restore API=%s and web=%s? Type ROLLBACK: ' "$PREVIOUS_API_IMAGE" "$PREVIOUS_WEB_IMAGE"
    read -r answer
    [[ "$answer" == ROLLBACK ]] || die "rollback cancelled"
  fi
  export BACKEND_IMAGE="$PREVIOUS_API_IMAGE" FRONTEND_IMAGE="$PREVIOUS_WEB_IMAGE"
  compose up -d --no-deps claudygod-api claudygod-web
  health --wait
  info "Application images restored. Database migrations were not reversed."
}

capture_previous_release() {
  local api_id web_id
  mkdir -p "$RELEASE_DIR"
  umask 077
  api_id="$(compose ps -q claudygod-api 2>/dev/null | head -n1)"
  web_id="$(compose ps -q claudygod-web 2>/dev/null | head -n1)"
  {
    printf 'PREVIOUS_API_IMAGE=%q\n' "$(if [[ -n "$api_id" ]]; then docker inspect --format '{{.Config.Image}}' "$api_id"; fi)"
    printf 'PREVIOUS_WEB_IMAGE=%q\n' "$(if [[ -n "$web_id" ]]; then docker inspect --format '{{.Config.Image}}' "$web_id"; fi)"
    printf 'CAPTURED_AT=%q\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$RELEASE_DIR/previous.env"
}

deploy() {
  local mode="${1:-all}"
  local -a pull_services start_services start_options
  case "$mode" in
    api) pull_services=(claudygod-api migrate); start_services=(claudygod-api); start_options=(--no-deps) ;;
    web) pull_services=(claudygod-web); start_services=(claudygod-web); start_options=(--no-deps) ;;
    all) pull_services=(redis claudygod-api migrate claudygod-web grafana); start_services=(redis claudygod-api claudygod-web grafana); start_options=(--remove-orphans) ;;
    *) die "deploy target must be api, web, or all" ;;
  esac
  validate_release_env
  BACKEND_IMAGE="${BACKEND_IMAGE%:*}:$TAG"
  FRONTEND_IMAGE="${FRONTEND_IMAGE%:*}:$TAG"
  export TAG BACKEND_IMAGE FRONTEND_IMAGE
  docker network inspect traefik-public >/dev/null 2>&1 || die "external network traefik-public does not exist"
  compose config --quiet
  capture_previous_release
  info "Pulling immutable release $TAG..."
  compose pull "${pull_services[@]}"
  if [[ "$mode" != web ]]; then
    info "Applying forward-compatible database migrations..."
    compose run --rm migrate
  fi
  compose up -d "${start_options[@]}" "${start_services[@]}"
  if ! health --wait; then
    info "Readiness failed; restoring previous application images..."
    rollback --non-interactive || true
    die "deployment failed; database migrations were not reversed"
  fi
  mkdir -p "$RELEASE_DIR"
  printf '{"tag":"%s","mode":"%s","deployedAt":"%s"}\n' "$TAG" "$mode" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$RELEASE_DIR/current.json"
  docker image prune -f --filter "until=168h" >/dev/null
  compose ps
}

command="${1:-}"
shift || true
load_env true
require_docker
case "$command" in
  deploy) deploy "${1:-all}" ;;
  rollback) rollback "${1:-}" ;;
  health) health "${1:-}" ;;
  *) die "usage: $0 {deploy [api|web|all]|rollback|health [--wait]}" ;;
esac
