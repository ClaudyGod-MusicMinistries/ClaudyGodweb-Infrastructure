#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
# shellcheck disable=SC1091 -- resolved relative to this script at runtime
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

POSTGRES_IMAGE=""

backup() {
  local retention="${BACKUP_RETENTION_DAYS:-30}" timestamp backup_file partial_file
  require_values SUPABASE_CONNECTION_STRING BACKUP_AGE_RECIPIENT
  require_command age
  [[ "$retention" =~ ^[0-9]+$ ]] || die "BACKUP_RETENTION_DAYS must be an integer"
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_file="$BACKUP_DIR/claudygod_db_${timestamp}.sql.gz.age"
  partial_file="$backup_file.partial"
  cleanup() { rm -f "$partial_file"; }
  trap cleanup EXIT INT TERM
  mkdir -p "$BACKUP_DIR"
  umask 077
  docker run --rm -e DATABASE_URL="$SUPABASE_CONNECTION_STRING" "$POSTGRES_IMAGE" \
    sh -ec 'pg_dump --dbname="$DATABASE_URL" --no-owner --no-privileges --clean --if-exists' \
    | gzip -9 | age --recipient "$BACKUP_AGE_RECIPIENT" --output "$partial_file"
  [[ -s "$partial_file" ]] || die "backup output is empty"
  mv "$partial_file" "$backup_file"
  find "$BACKUP_DIR" -type f -name 'claudygod_db_*.sql.gz.age' -mtime "+$retention" -delete
  if [[ -n "${AWS_BACKUP_BUCKET:-}" ]]; then
    require_command aws
    aws s3 cp "$backup_file" "${AWS_BACKUP_BUCKET%/}/$(basename "$backup_file")" --sse AES256 --storage-class STANDARD_IA
  fi
  trap - EXIT INT TERM
  info "Backup verified: $backup_file ($(du -h "$backup_file" | awk '{print $1}'))"
}

restore() {
  local backup_file="${1:-}" confirmation
  require_values SUPABASE_CONNECTION_STRING BACKUP_AGE_IDENTITY_FILE
  require_command age
  [[ -r "$BACKUP_AGE_IDENTITY_FILE" ]] || die "backup identity is not readable"
  [[ -n "$backup_file" ]] || backup_file="$(find "$BACKUP_DIR" -type f -name 'claudygod_db_*.sql.gz.age' -print 2>/dev/null | sort -r | head -n1)"
  [[ -f "$backup_file" ]] || die "no backup file found"
  printf 'Selected: %s\nType RESTORE to continue: ' "$backup_file"
  read -r confirmation
  [[ "$confirmation" == RESTORE ]] || die "restore cancelled"
  age --decrypt --identity "$BACKUP_AGE_IDENTITY_FILE" "$backup_file" | gunzip -c | \
    docker run --rm -i -e DATABASE_URL="$SUPABASE_CONNECTION_STRING" "$POSTGRES_IMAGE" \
      sh -ec 'psql --dbname="$DATABASE_URL" --set=ON_ERROR_STOP=1'
  info "Restore completed: $backup_file"
}

load_env true
POSTGRES_IMAGE="${POSTGRES_CLIENT_IMAGE:-postgres:16-alpine}"
require_docker
case "${1:-}" in
  backup) backup ;;
  restore) restore "${2:-}" ;;
  list) find "$BACKUP_DIR" -maxdepth 1 -type f -name 'claudygod_db_*.sql.gz.age' -printf '%TY-%Tm-%Td %TH:%TM %10s %p\n' 2>/dev/null | sort -r ;;
  shell) require_values SUPABASE_CONNECTION_STRING; exec docker run --rm -it postgres:16-alpine psql "$SUPABASE_CONNECTION_STRING" ;;
  *) die "usage: $0 {backup|restore [file]|list|shell}" ;;
esac
