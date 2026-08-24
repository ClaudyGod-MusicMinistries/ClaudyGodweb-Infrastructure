#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"
[[ -r "$ENV_FILE" ]] || { printf 'ERROR: missing %s\n' "$ENV_FILE" >&2; exit 1; }
env_mode="$(stat -c '%a' "$ENV_FILE")"
[[ "$env_mode" == 600 || "$env_mode" == 400 ]] || { printf 'ERROR: %s must have mode 0600 or 0400 (currently %s)\n' "$ENV_FILE" "$env_mode" >&2; exit 1; }
# The production environment file is trusted operator input and must be mode 0600.
# shellcheck source=/dev/null
source "$ENV_FILE"
required=(DOMAIN API_DOMAIN GRAFANA_DOMAIN TAG BACKEND_IMAGE FRONTEND_IMAGE SUPABASE_CONNECTION_STRING REDIS_PASSWORD JWT_KEY ENCRYPTION_KEY INTERNAL_API_KEY EMAIL_SMTP_HOST EMAIL_SMTP_USERNAME EMAIL_SMTP_PASSWORD GRAFANA_ADMIN_PASSWORD STORAGE_WEBSITE_S3_ENDPOINT STORAGE_WEBSITE_S3_ACCESS_KEY_ID STORAGE_WEBSITE_S3_SECRET_ACCESS_KEY STORAGE_WEBSITE_BUCKET STORAGE_WEBSITE_PUBLIC_BASE_URL BACKUP_AGE_RECIPIENT)
failed=0
for name in "${required[@]}"; do
  value="${!name:-}"
  if [[ -z "$value" || "$value" == *CHANGE_ME* || "$value" == *CHANGE-ME* || "$value" == *REPLACE_ME* ]]; then
    printf 'ERROR: %s is missing or contains a placeholder\n' "$name" >&2
    failed=1
  fi
done
[[ "${TAG:-}" =~ ^sha-[0-9A-Za-z._-]+$ ]] || { printf 'ERROR: TAG must begin with sha-\n' >&2; failed=1; }
[[ ${#INTERNAL_API_KEY} -ge 32 ]] || { printf 'ERROR: INTERNAL_API_KEY must be at least 32 characters\n' >&2; failed=1; }
exit "$failed"
