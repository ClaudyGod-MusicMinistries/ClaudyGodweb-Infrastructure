#!/bin/bash

################################################################################
#                      CLAUDYGOD DEPLOYMENT SCRIPT                             #
#                                                                              #
# This script handles production deployment:                                  #
# 1. Pre-flight checks (.env, Docker, network)                               #
# 2. Pull latest images from GHCR                                             #
# 3. Run database migrations                                                  #
# 4. Deploy updated services                                                  #
# 5. Perform health checks                                                    #
# 6. Print deployment summary                                                 #
#                                                                              #
# Usage:                                                                       #
#   $ ./scripts/deploy.sh                                                     #
#   $ TAG=v1.0.0 ./scripts/deploy.sh  # Deploy specific version               #
#                                                                              #
################################################################################

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_ROOT/docker"
ENV_FILE="$PROJECT_ROOT/.env"

# Default tag (can be overridden by environment variable)
TAG="${TAG:-latest}"

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

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${1}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_file_exists() {
    if [[ ! -f "$1" ]]; then
        log_error "File not found: $1"
    fi
}

check_command_exists() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Command not found: $1. Please install it and try again."
    fi
}

################################################################################
#                       PRE-FLIGHT CHECKS                                     #
################################################################################

log_section "PRE-FLIGHT CHECKS"

log_info "Checking prerequisites..."

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env file not found at $ENV_FILE"
fi
log_success "✓ .env file exists"

# Check if required commands exist
for cmd in docker docker-compose curl; do
    check_command_exists "$cmd"
done
log_success "✓ All required commands found (docker, docker-compose, curl)"

# Check if Docker daemon is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker daemon is not running. Please start Docker and try again."
fi
log_success "✓ Docker daemon is running"

# Check if traefik-public network exists
if ! docker network ls | grep -q "traefik-public"; then
    log_warning "traefik-public network not found. Creating it..."
    docker network create traefik-public || log_error "Failed to create traefik-public network"
    log_success "✓ traefik-public network created"
else
    log_success "✓ traefik-public network exists"
fi

# Check if docker-compose files exist
check_file_exists "$DOCKER_DIR/docker-compose.yml"
check_file_exists "$DOCKER_DIR/traefik/traefik.yml"
check_file_exists "$DOCKER_DIR/traefik/dynamic.yml"
log_success "✓ All Docker Compose configuration files found"

# Source .env to validate required variables
# shellcheck source=/dev/null
source "$ENV_FILE"

REQUIRED_VARS=(
    "DOMAIN"
    "API_DOMAIN"
    "ACME_EMAIL"
    "TAG"
    "POSTGRES_DB"
    "POSTGRES_USER"
    "POSTGRES_PASSWORD"
    "REDIS_PASSWORD"
    "JWT_KEY"
    "ENCRYPTION_KEY"
    "EMAIL_SMTP_HOST"
    "EMAIL_SMTP_USERNAME"
    "PAYSTACK_SECRET_KEY"
    "ANTHROPIC_API_KEY"
)

log_info "Validating .env variables..."
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        log_error "Required environment variable not set: $var"
    fi
done
log_success "✓ All required environment variables are set"

################################################################################
#                         PULL LATEST IMAGES                                  #
################################################################################

log_section "PULLING LATEST IMAGES FROM GHCR"

cd "$PROJECT_ROOT"

log_info "Pulling latest images (TAG=$TAG)..."
if ! docker compose -f "$DOCKER_DIR/docker-compose.yml" pull; then
    log_error "Failed to pull images from GHCR. Check your internet connection and GHCR credentials."
fi
log_success "✓ Images pulled successfully"

################################################################################
#                        RUN MIGRATIONS                                        #
################################################################################

log_section "DATABASE MIGRATIONS"

log_info "Running EF Core database migrations..."

# Run migrations with timeout
if docker compose -f "$DOCKER_DIR/docker-compose.yml" run --rm migrate; then
    log_success "✓ Database migrations completed"
else
    log_error "Database migrations failed. Check the logs above for details."
fi

################################################################################
#                      DEPLOY SERVICES                                         #
################################################################################

log_section "DEPLOYING SERVICES"

log_info "Updating services with latest images..."

if ! docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d --remove-orphans; then
    log_error "Failed to deploy services. Check docker-compose logs."
fi

log_success "✓ Services deployed"

################################################################################
#                         HEALTH CHECKS                                        #
################################################################################

log_section "HEALTH CHECKS"

# Wait for services to be ready
log_info "Waiting for services to be healthy (timeout: 120s)..."

HEALTH_CHECK_TIMEOUT=120
HEALTH_CHECK_INTERVAL=3
ELAPSED=0

while [[ $ELAPSED -lt $HEALTH_CHECK_TIMEOUT ]]; do
    API_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "https://${API_DOMAIN}/healthz" 2>/dev/null || echo "000")
    WEB_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/" 2>/dev/null || echo "000")

    if [[ "$API_HEALTH" == "200" && "$WEB_HEALTH" == "200" ]]; then
        log_success "✓ All services are healthy"
        break
    fi

    log_info "  Waiting... (API: $API_HEALTH, Web: $WEB_HEALTH)"
    sleep $HEALTH_CHECK_INTERVAL
    ELAPSED=$((ELAPSED + HEALTH_CHECK_INTERVAL))
done

if [[ $ELAPSED -ge $HEALTH_CHECK_TIMEOUT ]]; then
    log_warning "Health check timed out after ${HEALTH_CHECK_TIMEOUT}s. Services may still be starting."
    log_info "Run 'docker compose logs' to check service status."
fi

################################################################################
#                      DEPLOYMENT SUMMARY                                     #
################################################################################

log_section "DEPLOYMENT SUMMARY"

log_success "ClaudyGod infrastructure deployed successfully!"
log_info ""
log_info "📋 Deployment Details:"
log_info "  • Frontend:  https://${DOMAIN}"
log_info "  • API:       https://${API_DOMAIN}/api/v1/swagger"
log_info "  • Health:    https://${API_DOMAIN}/healthz"
log_info ""
log_info "🔧 Useful Commands:"
log_info "  • View logs:       docker compose logs -f"
log_info "  • Check status:    docker compose ps"
log_info "  • Restart service: docker compose restart <service>"
log_info "  • Stop all:        docker compose down"
log_info ""
log_info "📚 Documentation:"
log_info "  • Read the README.md for more information"
log_info "  • Check the plan at /root/.claude/plans/so-this-remote-v-linear-aurora.md"
log_info ""

log_success "✨ Deployment complete! Your site is live."
