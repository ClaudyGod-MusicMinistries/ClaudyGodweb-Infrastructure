.PHONY: help deploy pull logs ps restart down maintenance db-backup db-restore k8s-apply k8s-status k8s-logs-api k8s-rollout clean lint

# Default target
.DEFAULT_GOAL := help

# Project root
PROJECT_ROOT := $(CURDIR)
DOCKER_COMPOSE := docker compose -f $(PROJECT_ROOT)/docker/docker-compose.yml
DOCKER_COMPOSE_MAINT := docker compose -f $(PROJECT_ROOT)/docker/docker-compose.yml -f $(PROJECT_ROOT)/docker/docker-compose.maintenance.yml

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

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
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(deploy|pull|logs|ps|restart|down|maintenance)' | sed 's/: .*## /:\t/' | column -t -s '$$' | sed 's/:.*## /\t— /'
	@echo ""
	@echo "$(YELLOW)DATABASE OPERATIONS:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(db-)' | sed 's/: .*## /:\t/' | column -t -s '$$' | sed 's/:.*## /\t— /'
	@echo ""
	@echo "$(YELLOW)KUBERNETES (ALTERNATIVE):$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(k8s-)' | sed 's/: .*## /:\t/' | column -t -s '$$' | sed 's/:.*## /\t— /'
	@echo ""
	@echo "$(YELLOW)DEVELOPMENT & MAINTENANCE:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(clean|lint)' | sed 's/: .*## /:\t/' | column -t -s '$$' | sed 's/:.*## /\t— /'
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

logs-db: ## Follow database service logs
	$(DOCKER_COMPOSE) logs -f --tail=50 db

logs-redis: ## Follow Redis service logs
	$(DOCKER_COMPOSE) logs -f --tail=50 redis

logs-traefik: ## Follow Traefik reverse proxy logs
	$(DOCKER_COMPOSE) logs -f --tail=50 traefik

ps: ## Show status of all services
	@echo "$(BLUE)Service Status:$(NC)"
	$(DOCKER_COMPOSE) ps
	@echo ""
	@echo "$(BLUE)Docker Volumes:$(NC)"
	@docker volume ls | grep claudygod || echo "No volumes found"
	@echo ""
	@echo "$(BLUE)Docker Networks:$(NC)"
	@docker network ls | grep claudygod || echo "No networks found"

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

maintenance: ## Enable maintenance mode (503 Service Unavailable)
	@echo "$(YELLOW)⚠ Enabling maintenance mode...$(NC)"
	$(DOCKER_COMPOSE_MAINT) up -d
	@echo "$(YELLOW)Maintenance mode enabled.$(NC)"
	@echo "To disable: make deploy"

maintenance-off: ## Disable maintenance mode and redeploy services
	@echo "$(BLUE)▶ Disabling maintenance mode...$(NC)"
	$(DOCKER_COMPOSE) up -d
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
	@ls -lht $(PROJECT_ROOT)/backups/*.sql.gz 2>/dev/null | awk '{print $$9, "(" $$5 ")"}'

db-shell: ## Open interactive PostgreSQL shell
	@echo "$(BLUE)▶ Connecting to PostgreSQL...$(NC)"
	docker exec -it claudygod_db psql -U $$(grep POSTGRES_USER $(PROJECT_ROOT)/.env | cut -d= -f2)

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

clean: ## Remove stopped containers, dangling images, and old logs
	@echo "$(YELLOW)▶ Cleaning up Docker artifacts...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✓ Cleanup complete!$(NC)"

clean-all: ## DESTRUCTIVE: Remove all claudygod containers, images, and volumes
	@echo "$(RED)⚠ WARNING: This will delete all ClaudyGod containers, images, and volumes!$(NC)"
	@echo "This action cannot be undone. Press Ctrl+C to cancel."
	@sleep 3
	@echo "$(RED)Proceeding with full cleanup...$(NC)"
	docker compose -f $(DOCKER_COMPOSE) down -v
	docker system prune -af --volumes
	@echo "$(GREEN)✓ Full cleanup complete!$(NC)"

lint: ## Validate docker-compose.yml syntax
	@echo "$(BLUE)▶ Validating docker-compose.yml...$(NC)"
	$(DOCKER_COMPOSE) config > /dev/null
	@echo "$(GREEN)✓ Configuration is valid!$(NC)"

env-check: ## Verify .env file has all required variables
	@echo "$(BLUE)▶ Checking environment variables...$(NC)"
	@bash -c 'source $(PROJECT_ROOT)/.env 2>/dev/null; \
		for var in DOMAIN API_DOMAIN TAG POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD REDIS_PASSWORD JWT_KEY ENCRYPTION_KEY EMAIL_SMTP_HOST; do \
			if [ -z "$${!var}" ]; then \
				echo "$(YELLOW)✗ Missing: $$var$(NC)"; \
			else \
				echo "$(GREEN)✓ $$var$(NC)"; \
			fi; \
		done'

version: ## Show versions of key components
	@echo "$(BLUE)Component Versions:$(NC)"
	@echo "  Docker:          $$(docker --version)"
	@echo "  Docker Compose:  $$(docker compose version)"
	@echo "  Traefik:         v3.3"
	@echo "  PostgreSQL:      16-alpine"
	@echo "  Redis:           7-alpine"
	@echo "  .NET:            8.0"
	@echo "  Next.js:         14+"

health-check: ## Check health of all services
	@echo "$(BLUE)▶ Performing health checks...$(NC)"
	@bash -c 'source $(PROJECT_ROOT)/.env; \
		echo "API Health: $$(curl -s -o /dev/null -w "%{http_code}" https://$${API_DOMAIN}/healthz 2>/dev/null || echo "000")"; \
		echo "Web Health: $$(curl -s -o /dev/null -w "%{http_code}" https://$${DOMAIN}/ 2>/dev/null || echo "000")"'

info: ## Display deployment information
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║         ClaudyGod Infrastructure Deployment            ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@bash -c 'source $(PROJECT_ROOT)/.env 2>/dev/null; \
		echo "$(YELLOW)Configuration:$(NC)"; \
		echo "  Frontend:        https://$${DOMAIN}"; \
		echo "  API:             https://$${API_DOMAIN}"; \
		echo "  Tag:             $${TAG}"; \
		echo "  Database:        $${POSTGRES_DB}"; \
		echo "  Redis:           Enabled"; \
		echo ""' \
		echo "$(YELLOW)Services:$(NC)"; \
		echo "  Traefik:         Reverse proxy + TLS"; \
		echo "  PostgreSQL:      16-alpine (primary DB)"; \
		echo "  Redis:           7-alpine (cache)"; \
		echo "  API:             .NET 8 (Clean Architecture)"; \
		echo "  Web:             Next.js 14+ (frontend)"; \
		echo ""

################################################################################
#                            UTILITY TARGETS                                   #
################################################################################

.PHONY: all
all: deploy ## Alias for deploy

.PHONY: status
status: ps ## Alias for ps

.PHONY: validate
validate: lint env-check ## Validate config and environment
	@echo "$(GREEN)✓ All validations passed!$(NC)"
