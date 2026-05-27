.PHONY: help deploy pull logs logs-api logs-web logs-redis logs-traefik ps \
        restart restart-api restart-web down maintenance maintenance-off \
        db-backup db-restore db-list db-shell \
        k8s-apply k8s-status k8s-logs-api k8s-logs-web k8s-rollout k8s-scale-api k8s-port-forward-api k8s-delete \
        clean clean-all lint env-check version health-check info all status validate \
        rebuild rebuild-clean rebuild-images rebuild-deploy

.DEFAULT_GOAL := help

# ─────────────────────────────────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────────────────────────────────
PROJECT_ROOT := $(CURDIR)
ENV_FILE     := $(PROJECT_ROOT)/.env
COMPOSE_FILE := $(PROJECT_ROOT)/docker/docker-compose.yml
MAINT_FILE   := $(PROJECT_ROOT)/docker/docker-compose.maintenance.yml

# Compose wrappers. --env-file is REQUIRED: .env is at the repo root, compose
# file is under docker/, so Compose can't find .env on its own.
DOCKER_COMPOSE := docker compose \
                  --env-file $(ENV_FILE) \
                  --project-directory $(PROJECT_ROOT) \
                  -f $(COMPOSE_FILE)

DOCKER_COMPOSE_MAINT := docker compose \
                  --env-file $(ENV_FILE) \
                  --project-directory $(PROJECT_ROOT) \
                  -f $(COMPOSE_FILE) -f $(MAINT_FILE)

# ─────────────────────────────────────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────────────────────────────────────
BLUE   := \033[0;34m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m

################################################################################
#                              HELP                                            #
################################################################################

help: ## Display this help message
	@echo ""
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║   ClaudyGod Music Ministries — Infrastructure Commands   ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)PRODUCTION DEPLOYMENT:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(deploy|pull|logs|ps|restart|down|maintenance)' | awk -F':.*## ' '{printf "  %-22s %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)DATABASE OPERATIONS:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^db-' | awk -F':.*## ' '{printf "  %-22s %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)KUBERNETES (ALTERNATIVE):$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^k8s-' | awk -F':.*## ' '{printf "  %-22s %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)DEVELOPMENT & MAINTENANCE:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(clean|lint|env-check|version|health-check|info|validate)' | awk -F':.*## ' '{printf "  %-22s %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make deploy          # Pull latest images and deploy"
	@echo "  make logs            # Follow production logs"
	@echo "  make db-backup       # Backup PostgreSQL database"
	@echo "  make restart         # Restart all services"
	@echo "  make maintenance     # Enable maintenance mode"
	@echo ""

################################################################################
#                      PRODUCTION DEPLOYMENT TARGETS                          #
################################################################################

deploy: ## Pull images and deploy all services (full deployment)
	@echo "$(BLUE)▶ Deploying ClaudyGod infrastructure...$(NC)"
	$(DOCKER_COMPOSE) pull
	$(DOCKER_COMPOSE) up -d --remove-orphans
	@echo "$(GREEN)✓ Deployment complete!$(NC)"

pull: ## Pull latest images from GHCR without deploying
	@echo "$(BLUE)▶ Pulling latest images...$(NC)"
	$(DOCKER_COMPOSE) pull
	@echo "$(GREEN)✓ Images pulled!$(NC)"

logs: ## Follow production logs (all services)
	$(DOCKER_COMPOSE) logs -f --tail=100

logs-api: ## Follow API service logs
	$(DOCKER_COMPOSE) logs -f --tail=50 api

logs-web: ## Follow web (frontend) service logs
	$(DOCKER_COMPOSE) logs -f --tail=50 web

logs-redis: ## Follow Redis service logs
	$(DOCKER_COMPOSE) logs -f --tail=50 redis

logs-traefik: ## Follow Traefik logs from the shared proxy
	docker logs -f --tail=50 shared_traefik

ps: ## Show status of all services
	@echo "$(BLUE)Service Status:$(NC)"
	$(DOCKER_COMPOSE) ps
	@echo ""
	@echo "$(BLUE)Docker Volumes:$(NC)"
	@docker volume ls | grep claudygod || echo "No volumes found"
	@echo ""
	@echo "$(BLUE)Docker Networks:$(NC)"
	@docker network ls | grep -E "claudygod|traefik-public" || echo "No networks found"

restart: ## Restart all services
	@echo "$(BLUE)▶ Restarting services...$(NC)"
	$(DOCKER_COMPOSE) restart
	@echo "$(GREEN)✓ Services restarted!$(NC)"

restart-api: ## Restart API service only
	$(DOCKER_COMPOSE) restart api

restart-web: ## Restart web (frontend) service only
	$(DOCKER_COMPOSE) restart web

down: ## Stop and remove all containers (keeps volumes)
	@echo "$(YELLOW)⚠ Stopping all services...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ All services stopped!$(NC)"

################################################################################
#                         MAINTENANCE MODE                                     #
################################################################################

maintenance: ## Enable maintenance mode (503 via shared error-service)
	@echo "$(YELLOW)⚠ Enabling maintenance mode...$(NC)"
	$(DOCKER_COMPOSE_MAINT) up -d
	@echo "$(YELLOW)Maintenance mode enabled. Disable with: make maintenance-off$(NC)"

maintenance-off: ## Disable maintenance mode and bring stack back live
	@echo "$(BLUE)▶ Disabling maintenance mode...$(NC)"
	$(DOCKER_COMPOSE) up -d --remove-orphans
	@echo "$(GREEN)✓ Services live again!$(NC)"

################################################################################
#                       DATABASE OPERATIONS                                    #
################################################################################

db-backup: ## Backup PostgreSQL database with timestamp
	@echo "$(BLUE)▶ Starting database backup...$(NC)"
	$(PROJECT_ROOT)/scripts/backup.sh

db-restore: ## Restore PostgreSQL database from backup (interactive)
	@echo "$(BLUE)▶ Starting database restore...$(NC)"
	$(PROJECT_ROOT)/scripts/restore.sh

db-list: ## List all available database backups
	@echo "$(BLUE)Available backups:$(NC)"
	@ls -lht $(PROJECT_ROOT)/backups/*.sql.gz 2>/dev/null | awk '{print $$9, "(" $$5 ")"}' || echo "No backups found."

db-shell: ## Open interactive psql shell to Supabase
	@echo "$(BLUE)▶ Connecting to Supabase Postgres...$(NC)"
	@export $$(grep -v '^#' $(ENV_FILE) | grep -v '^\s*$$' | xargs); \
	docker run --rm -it postgres:16-alpine psql "$$SUPABASE_CONNECTION_STRING"

################################################################################
#                      KUBERNETES OPERATIONS                                   #
################################################################################

k8s-apply: ## Deploy to Kubernetes cluster (requires kubectl)
	@echo "$(BLUE)▶ Deploying to Kubernetes...$(NC)"
	kubectl apply -k $(PROJECT_ROOT)/k8s/
	@echo "$(GREEN)✓ Kubernetes deployment complete!$(NC)"

k8s-status: ## Show status of all Kubernetes resources in claudygod namespace
	@echo "$(BLUE)Kubernetes Resources:$(NC)"
	kubectl get all -n claudygod
	@echo ""
	@echo "$(BLUE)Pods:$(NC)"
	kubectl get pods -n claudygod -o wide

k8s-logs-api: ## Follow API pod logs
	kubectl logs -n claudygod -l app=cgm-api -f

k8s-logs-web: ## Follow web pod logs
	kubectl logs -n claudygod -l app=cgm-web -f

k8s-rollout: ## Restart all deployments (rolling update)
	@echo "$(BLUE)▶ Rolling restart of all deployments...$(NC)"
	kubectl rollout restart deployment -n claudygod
	kubectl rollout status deployment -n claudygod

k8s-scale-api: ## Scale API deployment (usage: make k8s-scale-api REPLICAS=5)
	@kubectl scale deployment cgm-api --replicas=$(REPLICAS) -n claudygod

k8s-port-forward-api: ## Forward API pod port to localhost:8080
	@echo "Forwarding localhost:8080 → API pod:8080"
	kubectl port-forward -n claudygod svc/cgm-api 8080:8080

k8s-delete: ## Delete all Kubernetes resources in claudygod namespace (DESTRUCTIVE)
	@echo "$(YELLOW)⚠ Deleting all Kubernetes resources...$(NC)"
	kubectl delete -k $(PROJECT_ROOT)/k8s/
	@echo "$(GREEN)✓ Kubernetes resources deleted!$(NC)"

################################################################################
#                    DEVELOPMENT & MAINTENANCE                                 #
################################################################################

clean: ## Remove stopped containers and dangling images
	@echo "$(YELLOW)▶ Cleaning up Docker artifacts...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✓ Cleanup complete!$(NC)"

clean-all: ## DESTRUCTIVE: Remove all claudygod containers, images, and volumes
	@echo "$(RED)⚠ This will delete ALL ClaudyGod containers, images, and volumes!$(NC)"
	@echo "Press Ctrl+C to cancel..."
	@sleep 3
	$(DOCKER_COMPOSE) down -v --remove-orphans
	docker system prune -af --volumes
	@echo "$(GREEN)✓ Full cleanup complete!$(NC)"

lint: ## Validate docker-compose.yml syntax
	@echo "$(BLUE)▶ Validating docker-compose.yml...$(NC)"
	$(DOCKER_COMPOSE) config > /dev/null
	@echo "$(GREEN)✓ Configuration is valid!$(NC)"

env-check: ## Verify .env file has all required variables filled in
	@echo "$(BLUE)▶ Checking environment variables...$(NC)"
	@export $$(grep -v '^#' $(ENV_FILE) | grep -v '^\s*$$' | xargs); \
	missing=0; \
	for var in DOMAIN API_DOMAIN TAG REGISTRY BACKEND_IMAGE FRONTEND_IMAGE \
	           SUPABASE_CONNECTION_STRING REDIS_PASSWORD JWT_KEY ENCRYPTION_KEY \
	           EMAIL_SMTP_HOST EMAIL_SMTP_USERNAME EMAIL_SMTP_PASSWORD \
	           EMAIL_FROM_ADDRESS CLAUDE_MODEL; do \
	  val=$$(eval echo "\$$$$var"); \
	  if [ -z "$$val" ] || echo "$$val" | grep -q "CHANGE_ME"; then \
	    printf "  $(RED)✗ Missing or placeholder:$(NC) %s\n" "$$var"; missing=1; \
	  else \
	    printf "  $(GREEN)✓$(NC) %s\n" "$$var"; \
	  fi; \
	done; \
	echo ""; \
	echo "$(YELLOW)Optional (set when ready):$(NC)"; \
	for var in PAYSTACK_SECRET_KEY NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY ANTHROPIC_API_KEY; do \
	  val=$$(eval echo "\$$$$var"); \
	  if [ -z "$$val" ] || echo "$$val" | grep -q "CHANGE_ME"; then \
	    printf "  $(YELLOW)⊘$(NC) %s (not yet configured)\n" "$$var"; \
	  else \
	    printf "  $(GREEN)✓$(NC) %s\n" "$$var"; \
	  fi; \
	done; \
	exit $$missing

version: ## Show versions of key components
	@echo "$(BLUE)Component Versions:$(NC)"
	@echo "  Docker:          $$(docker --version)"
	@echo "  Docker Compose:  $$(docker compose version)"
	@echo "  Traefik:         v3.6 (shared proxy)"
	@echo "  PostgreSQL:      Supabase (managed)"
	@echo "  Redis:           7-alpine"
	@echo "  .NET:            8.0"
	@echo "  Next.js:         14+"

health-check: ## Check health of all public endpoints
	@echo "$(BLUE)▶ Performing health checks...$(NC)"
	@export $$(grep -v '^#' $(ENV_FILE) | grep -v '^\s*$$' | xargs); \
	for url in "https://$$DOMAIN/" "https://$$API_DOMAIN/healthz"; do \
	  code=$$(curl -sSo /dev/null -w "%{http_code}" "$$url" || echo "000"); \
	  if echo "$$code" | grep -qE '^2'; then \
	    printf "  $(GREEN)✓$(NC) %s → %s\n" "$$url" "$$code"; \
	  else \
	    printf "  $(RED)✗$(NC) %s → %s\n" "$$url" "$$code"; \
	  fi; \
	done

info: ## Display deployment information
	@echo "$(BLUE)╔════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║         ClaudyGod Infrastructure Deployment            ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@export $$(grep -v '^#' $(ENV_FILE) | grep -v '^\s*$$' | xargs); \
	echo "$(YELLOW)Configuration:$(NC)"; \
	echo "  Frontend:        https://$$DOMAIN"; \
	echo "  API:             https://$$API_DOMAIN"; \
	echo "  Grafana:         https://$$GRAFANA_DOMAIN"; \
	echo "  Backend image:   $$BACKEND_IMAGE"; \
	echo "  Frontend image:  $$FRONTEND_IMAGE"; \
	echo ""; \
	echo "$(YELLOW)Services:$(NC)"; \
	echo "  Shared proxy:    Traefik v3.6 (~/apps/proxy)"; \
	echo "  Database:        Supabase Postgres (managed)"; \
	echo "  Email:           Brevo SMTP relay"; \
	echo "  Redis:           Local (claudygod_redis)"; \
	echo ""

################################################################################
#                            UTILITY TARGETS                                   #
################################################################################

all: deploy ## Alias for deploy
status: ps ## Alias for ps
validate: lint env-check ## Validate config and environment
	@echo "$(GREEN)✓ All validations passed!$(NC)"

################################################################################
#                        REBUILD & CLEAN TARGETS                               #
################################################################################

rebuild: rebuild-clean rebuild-images rebuild-deploy ## Complete rebuild from scratch

rebuild-clean: ## Remove containers & images (preserves volumes & Let's Encrypt)
	@echo "$(BLUE)▶ Cleaning old containers and images...$(NC)"
	$(DOCKER_COMPOSE) down --remove-orphans
	@docker rmi ghcr.io/claudygod-musicministries/cgm-api:latest 2>/dev/null || true
	@docker rmi ghcr.io/claudygod-musicministries/cgm-web:latest 2>/dev/null || true
	@echo "$(GREEN)✓ Clean complete (Let's Encrypt preserved)$(NC)"

rebuild-images: ## Pull fresh images from GHCR
	@echo "$(BLUE)▶ Pulling fresh images from GHCR...$(NC)"
	$(DOCKER_COMPOSE) pull
	@echo "$(GREEN)✓ Images pulled$(NC)"

rebuild-deploy: env-check ## Deploy fresh infrastructure
	@echo "$(BLUE)▶ Running database migrations...$(NC)"
	$(DOCKER_COMPOSE) run --rm migrate
	@echo "$(BLUE)▶ Starting all services...$(NC)"
	$(DOCKER_COMPOSE) up -d --remove-orphans
	@echo "$(GREEN)✓ Deployment complete$(NC)"
	@echo ""
	@echo "$(YELLOW)Waiting for services to stabilize...$(NC)"
	@sleep 20
	@echo ""
	@$(MAKE) ps
	@echo ""
	@echo "$(YELLOW)Run 'make health-check' to verify endpoints$(NC)"