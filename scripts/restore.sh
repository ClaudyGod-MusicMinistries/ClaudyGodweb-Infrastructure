#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
POSTGRES_IMAGE="${POSTGRES_CLIENT_IMAGE:-postgres:16-alpine}"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -r "$ENV_FILE" ]] || die "environment file not found: $ENV_FILE"
# shellcheck source=/dev/null
source "$ENV_FILE"
[[ -n "${SUPABASE_CONNECTION_STRING:-}" ]] || die "SUPABASE_CONNECTION_STRING is required"
command -v docker >/dev/null 2>&1 || die "docker is required"

BACKUP_FILE="${1:-}"
if [[ -z "$BACKUP_FILE" ]]; then
  BACKUP_FILE="$(find "$BACKUP_DIR" -type f -name 'claudygod_db_*.sql.gz' -print 2>/dev/null | sort -r | head -n 1)"
fi
[[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]] || die "no backup file found"
gzip -t "$BACKUP_FILE" || die "backup is corrupt or is not gzip data"

printf 'Selected: %s\n' "$BACKUP_FILE"
printf '%s\n' 'WARNING: this applies DROP/CREATE statements to the configured managed database.'
printf '%s' 'Type RESTORE to continue: '
read -r CONFIRMATION
[[ "$CONFIRMATION" == "RESTORE" ]] || die "restore cancelled"

gunzip -c "$BACKUP_FILE" | docker run --rm -i \
  -e DATABASE_URL="$SUPABASE_CONNECTION_STRING" \
  "$POSTGRES_IMAGE" \
  sh -ec 'psql --dbname="$DATABASE_URL" --set=ON_ERROR_STOP=1'

printf 'Restore completed successfully from %s\n' "$BACKUP_FILE"
