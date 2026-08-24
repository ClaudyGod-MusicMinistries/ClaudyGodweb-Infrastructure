#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
WAIT=false
[[ "${1:-}" == --wait ]] && WAIT=true
[[ -r "$ENV_FILE" ]] || { printf 'ERROR: missing %s\n' "$ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"
attempts=1
$WAIT && attempts=24
for ((attempt=1; attempt<=attempts; attempt++)); do
  api="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 10 "https://${API_DOMAIN}/healthz" 2>/dev/null)" || api=000
  web="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 10 "https://${DOMAIN}/" 2>/dev/null)" || web=000
  if [[ "$api" == 200 && "$web" =~ ^(200|301|302)$ ]]; then printf 'Healthy: API=%s web=%s\n' "$api" "$web"; exit 0; fi
  printf 'Not ready (%d/%d): API=%s web=%s\n' "$attempt" "$attempts" "$api" "$web" >&2
  (( attempt == attempts )) || sleep 5
done
exit 1
