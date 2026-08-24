#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
STATE_FILE="${RELEASE_DIR:-$PROJECT_ROOT/.releases}/previous.env"
[[ -r "$ENV_FILE" && -r "$STATE_FILE" ]] || { printf 'ERROR: rollback environment or state is missing\n' >&2; exit 1; }
[[ "$(stat -c '%a' "$ENV_FILE")" == 600 || "$(stat -c '%a' "$ENV_FILE")" == 400 ]] || { printf 'ERROR: environment file permissions are too broad\n' >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"
# shellcheck source=/dev/null
source "$STATE_FILE"
[[ -n "${PREVIOUS_API_IMAGE:-}" && -n "${PREVIOUS_WEB_IMAGE:-}" ]] || { printf 'ERROR: no complete previous release exists\n' >&2; exit 1; }
if [[ "${1:-}" != --non-interactive ]]; then
  printf 'Restore API=%s and web=%s? Type ROLLBACK: ' "$PREVIOUS_API_IMAGE" "$PREVIOUS_WEB_IMAGE"
  read -r answer
  [[ "$answer" == ROLLBACK ]] || { printf 'Rollback cancelled.\n'; exit 1; }
fi
export BACKEND_IMAGE="$PREVIOUS_API_IMAGE" FRONTEND_IMAGE="$PREVIOUS_WEB_IMAGE"
compose=(docker compose --env-file "$ENV_FILE" --project-directory "$PROJECT_ROOT" -f "$PROJECT_ROOT/docker/docker-compose.yml")
"${compose[@]}" up -d --no-deps claudygod-api claudygod-web
"$SCRIPT_DIR/health-check.sh" --wait
printf 'Application images restored. Database migrations were not reversed.\n'
