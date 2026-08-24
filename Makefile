.DEFAULT_GOAL := help
.PHONY: help validate deploy deploy-api deploy-web rollback health ps logs logs-api \
        logs-web restart restart-api restart-web down maintenance maintenance-off \
        backup restore backups db-shell clean clean-all

RELEASE := ./scripts/release.sh
DATABASE := ./scripts/database.sh
COMPOSE := ./scripts/compose.sh

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; print "ClaudyGod infrastructure\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

validate: ## Validate production environment, Compose, scripts, and policies
	./scripts/validate.sh --production

deploy: ## Deploy the complete immutable release
	$(RELEASE) deploy all

deploy-api: ## Deploy API and migrations
	$(RELEASE) deploy api

deploy-web: ## Deploy web only
	$(RELEASE) deploy web

rollback: ## Restore previous API and web images
	$(RELEASE) rollback

health: ## Check public API and web readiness
	$(RELEASE) health

ps: ## Show service state
	$(COMPOSE) ps

logs: ## Follow all service logs
	$(COMPOSE) logs -f --tail=100

logs-api: ## Follow API logs
	$(COMPOSE) logs -f --tail=100 claudygod-api

logs-web: ## Follow web logs
	$(COMPOSE) logs -f --tail=100 claudygod-web

restart: ## Restart all running services
	$(COMPOSE) restart

restart-api: ## Restart the API
	$(COMPOSE) restart claudygod-api

restart-web: ## Restart the web application
	$(COMPOSE) restart claudygod-web

down: ## Stop the stack and preserve volumes
	$(COMPOSE) down

maintenance: ## Enable hostname-scoped maintenance mode
	$(COMPOSE) maintenance-on

maintenance-off: ## Disable maintenance mode
	$(COMPOSE) maintenance-off

backup: ## Create an encrypted database backup
	$(DATABASE) backup

restore: ## Restore an encrypted database backup interactively
	$(DATABASE) restore

backups: ## List encrypted database backups
	$(DATABASE) list

db-shell: ## Open a PostgreSQL shell
	$(DATABASE) shell

clean: ## Remove stopped project containers
	$(COMPOSE) rm -f

clean-all: ## Delete this project's containers and volumes interactively
	@read -r -p "Type DELETE-CLAUDYGOD to continue: " answer; test "$$answer" = DELETE-CLAUDYGOD
	$(COMPOSE) down -v --remove-orphans
