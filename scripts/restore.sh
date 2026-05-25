#!/bin/bash

################################################################################
#                    DATABASE RESTORE SCRIPT                                   #
#                                                                              #
# Restore PostgreSQL database from backup with:                               #
# - Interactive backup selection                                              #
# - Automatic decompression                                                   #
# - Confirmation prompt before restore                                        #
# - Verification after restore                                                #
#                                                                              #
# Usage:                                                                       #
#   $ ./scripts/restore.sh                                                    #
#   $ ./scripts/restore.sh backups/claudygod_db_2024-01-15.sql.gz            #
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

################################################################################
#                          UTILITY FUNCTIONS                                   #
################################################################################

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
    exit 1
}

read_prompt() {
    local prompt="$1"
    local response
    read -p "$(echo -e ${BLUE})${prompt}$(echo -e ${NC})" response
    echo "$response"
}

################################################################################
#                       PRE-FLIGHT CHECKS                                     #
################################################################################

log_info "Starting database restore process..."
log_info ""

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env file not found at $ENV_FILE"
fi

# Source environment variables
# shellcheck source=/dev/null
source "$ENV_FILE"

# Verify required variables
if [[ -z "${POSTGRES_DB:-}" ]] || [[ -z "${POSTGRES_USER:-}" ]]; then
    log_error "Missing POSTGRES_DB or POSTGRES_USER in .env"
fi

# Check if backup directory exists
if [[ ! -d "$BACKUP_DIR" ]]; then
    log_error "Backup directory not found: $BACKUP_DIR"
fi

# Check if PostgreSQL container is running
if ! docker ps | grep -q "claudygod_db"; then
    log_error "PostgreSQL container (claudygod_db) is not running. Start it with: docker compose up -d db"
fi

################################################################################
#                      BACKUP FILE SELECTION                                  #
################################################################################

BACKUP_FILE="${1:-}"

# If no backup file provided, prompt user to select one
if [[ -z "$BACKUP_FILE" ]]; then
    log_info "Available backups:"
    log_info ""

    # Find all backup files and display them
    BACKUPS=()
    while IFS= read -r -d '' file; do
        BACKUPS+=("$file")
    done < <(find "$BACKUP_DIR" -name "claudygod_db*.sql.gz" -type f -printf '%T@\0%p\0' | sort -zrn | sed -z 's/[0-9]*\.\d*\x00//' | head -20z)

    if [[ ${#BACKUPS[@]} -eq 0 ]]; then
        log_error "No backup files found in $BACKUP_DIR"
    fi

    # Display options
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        FILESIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
        MODIFIED=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "${BACKUPS[$i]}" 2>/dev/null || \
                   stat --format='%y' "${BACKUPS[$i]}" 2>/dev/null | cut -d' ' -f1-2)
        echo -e "  ${BLUE}$((i+1))${NC}) $FILENAME ($FILESIZE) — $MODIFIED"
    done

    log_info ""
    CHOICE=$(read_prompt "Select backup to restore (1-${#BACKUPS[@]}): ")

    # Validate choice
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 )) || (( CHOICE > ${#BACKUPS[@]} )); then
        log_error "Invalid selection: $CHOICE"
    fi

    BACKUP_FILE="${BACKUPS[$((CHOICE-1))]}"
fi

# Verify backup file exists
if [[ ! -f "$BACKUP_FILE" ]]; then
    log_error "Backup file not found: $BACKUP_FILE"
fi

FILENAME=$(basename "$BACKUP_FILE")
FILESIZE=$(du -h "$BACKUP_FILE" | cut -f1)

log_success "Selected backup: $FILENAME ($FILESIZE)"
log_info ""

################################################################################
#                      RESTORATION CONFIRMATION                               #
################################################################################

log_warning "⚠️  DATABASE RESTORE WARNING"
log_info ""
log_info "You are about to restore the database from backup:"
log_info "  • File:     $FILENAME"
log_info "  • Database: $POSTGRES_DB"
log_info "  • User:     $POSTGRES_USER"
log_info ""
log_warning "This will REPLACE the current database with the backup content."
log_warning "All data in the current database will be lost."
log_info ""

CONFIRM=$(read_prompt "Type 'yes' to confirm restoration, or press Enter to cancel: ")

if [[ "$CONFIRM" != "yes" ]]; then
    log_info "Restoration cancelled."
    exit 0
fi

################################################################################
#                        PERFORM RESTORE                                      #
################################################################################

log_info ""
log_info "Starting restore process..."
log_info ""

# Decompress and restore
if gunzip -c "$BACKUP_FILE" | docker exec -i claudygod_db psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --no-password; then

    log_success "Database restore completed"
else
    log_error "Database restore failed. Check PostgreSQL container logs for details."
fi

################################################################################
#                        VERIFICATION                                         #
################################################################################

log_info ""
log_info "Verifying restore..."

# Check database tables
TABLE_COUNT=$(docker exec claudygod_db psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --no-password \
    -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")

if [[ "$TABLE_COUNT" -gt 0 ]]; then
    log_success "Database verification successful ($TABLE_COUNT tables found)"
else
    log_warning "Could not verify database tables. Check the restore manually."
fi

################################################################################
#                            SUMMARY                                           #
################################################################################

log_info ""
log_success "✨ Database restore completed!"
log_info ""
log_info "📋 Restore Details:"
log_info "  • Backup file: $FILENAME"
log_info "  • Database:    $POSTGRES_DB"
log_info "  • Tables:      $TABLE_COUNT"
log_info ""
log_info "🔧 Next steps:"
log_info "  1. Verify the application works correctly"
log_info "  2. Check the API health endpoint: https://${API_DOMAIN}/healthz"
log_info "  3. Review application logs if needed: docker compose logs api"
log_info ""
log_success "Restore complete. Your application should now be using the restored database."
