#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
POSTGRES_IMAGE="${POSTGRES_CLIENT_IMAGE:-postgres:16-alpine}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_FILE="$BACKUP_DIR/claudygod_db_${TIMESTAMP}.sql.gz"
PARTIAL_FILE="${BACKUP_FILE}.partial"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
cleanup() { rm -f "$PARTIAL_FILE"; }
trap cleanup EXIT INT TERM

[[ -r "$ENV_FILE" ]] || die "environment file not found: $ENV_FILE"
# shellcheck source=/dev/null
source "$ENV_FILE"
[[ -n "${SUPABASE_CONNECTION_STRING:-}" ]] || die "SUPABASE_CONNECTION_STRING is required"
[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "BACKUP_RETENTION_DAYS must be an integer"
command -v docker >/dev/null 2>&1 || die "docker is required"
docker info >/dev/null 2>&1 || die "Docker daemon is not available"

mkdir -p "$BACKUP_DIR"
umask 077
info "Creating encrypted-in-transit logical backup from managed PostgreSQL..."

docker run --rm \
  -e DATABASE_URL="$SUPABASE_CONNECTION_STRING" \
  "$POSTGRES_IMAGE" \
  sh -ec 'pg_dump --dbname="$DATABASE_URL" --no-owner --no-privileges --clean --if-exists' \
  | gzip -9 > "$PARTIAL_FILE"

gzip -t "$PARTIAL_FILE"
[[ -s "$PARTIAL_FILE" ]] || die "backup output is empty"
mv "$PARTIAL_FILE" "$BACKUP_FILE"

find "$BACKUP_DIR" -type f -name 'claudygod_db_*.sql.gz' -mtime "+$RETENTION_DAYS" -delete

if [[ -n "${AWS_BACKUP_BUCKET:-}" ]]; then
  command -v aws >/dev/null 2>&1 || die "AWS CLI is required for AWS_BACKUP_BUCKET"
  aws s3 cp "$BACKUP_FILE" "${AWS_BACKUP_BUCKET%/}/$(basename "$BACKUP_FILE")" \
    --sse AES256 --storage-class STANDARD_IA
fi

trap - EXIT INT TERM
info "Backup verified: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | awk '{print $1}'))"
