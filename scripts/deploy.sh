#!/usr/bin/env bash
################################################################################
#                      CLAUDYGOD DEPLOYMENT SCRIPT                             #
#                                                                              #
# Usage:                                                                       #
#   ./scripts/deploy.sh              # deploy all services (latest)           #
#   TAG=sha-abc123 ./scripts/deploy.sh  # deploy a pinned tag                 #
#   ./scripts/deploy.sh --api-only   # restart API + migrations only          #
#   ./scripts/deploy.sh --web-only   # restart web frontend only              #
#                                                                              #
################################################################################

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_ROOT/docker"
ENV_FILE="$PROJECT_ROOT/.env"
COMPOSE="docker compose --env-file $ENV_FILE --project-directory $PROJECT_ROOT -f $DOCKER_DIR/docker-compose.yml"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}→${NC}  $*"; }
success() { echo -e "${GREEN}✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
die()     { echo -e "${RED}✗${NC}  $*" >&2; exit 1; }
section() { echo -e "\n${BLUE}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# ── Args ──────────────────────────────────────────────────────────────────────
export TAG="${TAG:-latest}"
MODE="all"
[[ "${1:-}" == "--api-only" ]] && MODE="api"
[[ "${1:-}" == "--web-only" ]] && MODE="web"
[[ -z "${1:-}" || "${1:-}" == "--api-only" || "${1:-}" == "--web-only" ]] || \
  die "Unknown argument: ${1}. Use --api-only, --web-only, or no argument."

# ────────────────────────────────────────────────────────────────────────────
section "PRE-FLIGHT CHECKS"

[[ -f "$ENV_FILE" ]] || die ".env not found. Run: cp .env.example .env && fill in values."
success ".env file found"

command -v docker &>/dev/null || die "Docker not installed."
docker info &>/dev/null       || die "Docker daemon not running."
# Verify Docker Compose v2 plugin (not legacy docker-compose v1)
docker compose version &>/dev/null || die "Docker Compose v2 plugin not found. Run: apt install docker-compose-plugin"
success "Docker + Compose v2 are running"

# Ensure traefik-public network exists (shared proxy requires it)
if ! docker network ls --format '{{.Name}}' | grep -q '^traefik-public$'; then
  warn "traefik-public network missing — creating..."
  docker network create traefik-public
fi
success "traefik-public network exists"

# Validate required env vars (matches this infra's Supabase architecture)
source "$ENV_FILE"
REQUIRED_VARS=(
  DOMAIN API_DOMAIN
  BACKEND_IMAGE FRONTEND_IMAGE
  SUPABASE_CONNECTION_STRING
  REDIS_PASSWORD
  JWT_KEY ENCRYPTION_KEY INTERNAL_API_KEY
  EMAIL_SMTP_HOST EMAIL_SMTP_USERNAME EMAIL_SMTP_PASSWORD
  GRAFANA_ADMIN_PASSWORD
  STORAGE_WEBSITE_S3_ENDPOINT STORAGE_WEBSITE_S3_ACCESS_KEY_ID
  STORAGE_WEBSITE_S3_SECRET_ACCESS_KEY STORAGE_WEBSITE_BUCKET
  STORAGE_WEBSITE_PUBLIC_BASE_URL
)

# Optional variables (warn if missing, but don't block deployment)
OPTIONAL_VARS=(
  PAYSTACK_SECRET_KEY NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY
  AI_PROVIDER_API_KEY
)

info "Validating required environment variables..."
missing=0
for var in "${REQUIRED_VARS[@]}"; do
  val="${!var:-}"
  if [[ -z "$val" || "$val" == *CHANGE_ME* || "$val" == *CHANGE-ME* ]]; then
    echo -e "  ${RED}✗${NC} $var is missing or still set to a CHANGE_ME/CHANGE-ME placeholder"
    missing=1
  elif [[ "$var" == "INTERNAL_API_KEY" && ${#val} -lt 32 ]]; then
    echo -e "  ${RED}✗${NC} $var must contain at least 32 characters (required by AdminGateway:ApiKey)"
    missing=1
  else
    echo -e "  ${GREEN}✓${NC} $var"
  fi
done
[[ $missing -eq 0 ]] || die "Fix the missing variables above before deploying."
success "All required variables set"

info "Checking optional variables..."
for var in "${OPTIONAL_VARS[@]}"; do
  val="${!var:-}"
  if [[ -z "$val" || "$val" == *CHANGE_ME* ]]; then
    echo -e "  ${YELLOW}⊘${NC} $var not configured (payment/AI features disabled)"
  else
    echo -e "  ${GREEN}✓${NC} $var"
  fi
done
success "Validation complete"

# ────────────────────────────────────────────────────────────────────────────
section "PULLING IMAGES FROM GHCR (TAG=$TAG)"

case "$MODE" in
  api)  $COMPOSE pull claudygod-api migrate ;;
  web)  $COMPOSE pull claudygod-web ;;
  *)    $COMPOSE pull redis claudygod-api migrate claudygod-web grafana ;;
esac
success "Images pulled"

# ────────────────────────────────────────────────────────────────────────────
if [[ "$MODE" != "web" ]]; then
  section "DATABASE MIGRATIONS"
  $COMPOSE run --rm migrate || die "Migrations failed — aborting deploy."
  success "Migrations applied"
fi

# ────────────────────────────────────────────────────────────────────────────
section "DEPLOYING SERVICES"

case "$MODE" in
  api)
    $COMPOSE up -d --no-deps claudygod-api
    ;;
  web)
    $COMPOSE up -d --no-deps claudygod-web
    ;;
  *)
    $COMPOSE up -d --remove-orphans redis claudygod-api claudygod-web grafana
    ;;
esac
success "Services started"

# ────────────────────────────────────────────────────────────────────────────
section "HEALTH CHECKS"

TIMEOUT=120; ELAPSED=0; INTERVAL=5
API_HEALTH_URL="https://${API_DOMAIN}/healthz"
WEB_HEALTH_URL="https://${DOMAIN}/"
info "Waiting up to ${TIMEOUT}s for services to be healthy..."

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  API_CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$API_HEALTH_URL" 2>/dev/null) || API_CODE="000"
  WEB_CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$WEB_HEALTH_URL" 2>/dev/null) || WEB_CODE="000"

  if [[ "$API_CODE" == "200" && "$WEB_CODE" =~ ^(200|301|302)$ ]]; then
    success "All services healthy"
    break
  fi
  printf "  Waiting... (API: %s, Web: %s) [%ds]\n" "$API_CODE" "$WEB_CODE" "$ELAPSED"
  sleep $INTERVAL; ELAPSED=$((ELAPSED + INTERVAL))
done

if [[ $ELAPSED -ge $TIMEOUT ]]; then
  echo -e "\n${RED}API container diagnostics:${NC}" >&2
  $COMPOSE ps claudygod-api >&2 || true
  $COMPOSE logs --tail=100 claudygod-api >&2 || true
  die "Health check timed out — deployment is not healthy. API: ${API_HEALTH_URL}; Web: ${WEB_HEALTH_URL}."
fi

# Prune old images to free disk
docker image prune -f --filter "until=24h" >/dev/null

# ────────────────────────────────────────────────────────────────────────────
section "DEPLOYMENT SUMMARY"

success "ClaudyGod deployed successfully!"
echo ""
echo -e "  ${YELLOW}Frontend:${NC}  https://${DOMAIN}"
echo -e "  ${YELLOW}API:${NC}       ${API_HEALTH_URL}"
echo -e "  ${YELLOW}Grafana:${NC}   https://${GRAFANA_DOMAIN:-metrics.claudygod.org}"
echo ""
echo -e "  ${BLUE}make logs${NC}         — follow all logs"
echo -e "  ${BLUE}make ps${NC}           — show service status"
echo -e "  ${BLUE}make health-check${NC}  — re-run health checks"
echo ""
$COMPOSE ps
echo ""
success "Done — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
