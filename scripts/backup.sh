#!/bin/bash

################################################################################
#                    DATABASE BACKUP SCRIPT                                    #
#                                                                              #
# Automated PostgreSQL backup with:                                           #
# - pg_dump with compression                                                  #
# - Timestamped filenames                                                     #
# - Retention policy (30 daily, 12 weekly, 3 monthly)                         #
# - Optional S3 upload for offsite backup                                     #
#                                                                              #
# Usage:                                                                       #
#   $ ./scripts/backup.sh                                                     #
#   $ AWS_BACKUP_BUCKET=s3://backup-bucket ./scripts/backup.sh               #
#                                                                              #
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"
ENV_FILE="$PROJECT_ROOT/.env"

# Timestamps
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y-%m-%d)
WEEK=$(date +%W)
MONTH=$(date +%Y-%m)

# Backup filenames
DAILY_BACKUP="claudygod_db_${DATE}.sql.gz"
WEEKLY_BACKUP="claudygod_db_weekly_${DATE}_w${WEEK}.sql.gz"
MONTHLY_BACKUP="claudygod_db_monthly_${MONTH}.sql.gz"

################################################################################
#                          UTILITY FUNCTIONS                                   #
################################################################################

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
    exit 1
}

################################################################################
#                            BACKUP PROCESS                                    #
################################################################################

log_info "Starting database backup..."

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Source environment variables
if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env file not found at $ENV_FILE"
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

# Verify required variables
if [[ -z "${POSTGRES_DB:-}" ]] || [[ -z "${POSTGRES_USER:-}" ]]; then
    log_error "Missing POSTGRES_DB or POSTGRES_USER in .env"
fi

log_info "Database: $POSTGRES_DB"
log_info "User: $POSTGRES_USER"
log_info "Backup directory: $BACKUP_DIR"
log_info ""

# Check if PostgreSQL container is running
if ! docker ps | grep -q "claudygod_db"; then
    log_error "PostgreSQL container (claudygod_db) is not running"
fi

# Perform backup using pg_dump inside the container
log_info "Running pg_dump inside PostgreSQL container..."

BACKUP_FILE="$BACKUP_DIR/$DAILY_BACKUP"

if docker exec claudygod_db pg_dump \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --verbose \
    --no-password \
    | gzip -9 > "$BACKUP_FILE"; then

    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log_success "Backup created: $DAILY_BACKUP ($BACKUP_SIZE)"
else
    log_error "pg_dump failed. Check PostgreSQL credentials and container status."
fi

# Create symbolic links for weekly and monthly backups
# This allows keeping the same file for a week/month
if [[ -f "$BACKUP_FILE" ]]; then
    WEEKLY_LINK="$BACKUP_DIR/$WEEKLY_BACKUP"
    MONTHLY_LINK="$BACKUP_DIR/$MONTHLY_BACKUP"

    # Update weekly backup link
    rm -f "$WEEKLY_LINK"
    cp "$BACKUP_FILE" "$WEEKLY_LINK"
    log_info "Weekly backup: $WEEKLY_BACKUP"

    # Update monthly backup link
    rm -f "$MONTHLY_LINK"
    cp "$BACKUP_FILE" "$MONTHLY_LINK"
    log_info "Monthly backup: $MONTHLY_BACKUP"
fi

################################################################################
#                          RETENTION POLICY                                    #
################################################################################

log_info ""
log_info "Applying retention policy..."

# Keep last 30 daily backups
log_info "Keeping last 30 daily backups..."
find "$BACKUP_DIR" -name "claudygod_db_*.sql.gz" \( ! -name "*weekly*" ! -name "*monthly*" \) \
    -type f -mtime +30 -delete 2>/dev/null || true

# Keep last 12 weekly backups
log_info "Keeping last 12 weekly backups..."
find "$BACKUP_DIR" -name "claudygod_db_weekly*.sql.gz" \
    -type f -mtime +84 -delete 2>/dev/null || true  # 12 weeks = 84 days

# Keep last 3 monthly backups
log_info "Keeping last 3 monthly backups..."
find "$BACKUP_DIR" -name "claudygod_db_monthly*.sql.gz" \
    -type f -mtime +90 -delete 2>/dev/null || true  # 3 months ≈ 90 days

################################################################################
#                       OPTIONAL: S3 UPLOAD                                    #
################################################################################

if [[ -n "${AWS_BACKUP_BUCKET:-}" ]]; then
    log_info ""
    log_info "Uploading backup to S3: $AWS_BACKUP_BUCKET"

    if command -v aws &> /dev/null; then
        if aws s3 cp "$BACKUP_FILE" \
            "s3://$(echo $AWS_BACKUP_BUCKET | sed 's|s3://||')/$DAILY_BACKUP" \
            --sse AES256 \
            --storage-class STANDARD_IA; then
            log_success "Backup uploaded to S3"
        else
            log_error "Failed to upload backup to S3"
        fi
    else
        log_error "AWS CLI not found. Install it to enable S3 backups."
    fi
fi

################################################################################
#                            SUMMARY                                           #
################################################################################

log_info ""
log_success "✨ Backup completed successfully!"
log_info ""
log_info "📁 Backup Files:"
ls -lh "$BACKUP_DIR" | tail -5
log_info ""
log_info "💾 Most Recent Backups:"
ls -lt "$BACKUP_DIR" | head -4 | tail -3
log_info ""
log_success "Backup location: $BACKUP_DIR"
