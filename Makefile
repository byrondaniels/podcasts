.PHONY: help setup up down restart logs shell-backend shell-frontend shell-mongo clean rebuild init-db test lint

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Podcast Subscription App - Docker Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

setup: ## Initial setup - copy .env.example to .env
	@echo "$(BLUE)Setting up environment...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)✓ Created .env file from .env.example$(NC)"; \
		echo "$(YELLOW)⚠ Please edit .env and add your OPENAI_API_KEY$(NC)"; \
	else \
		echo "$(YELLOW).env file already exists$(NC)"; \
	fi

up: ## Start all services
	@echo "$(BLUE)Starting all services...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo ""
	@echo "$(BLUE)Service URLs:$(NC)"
	@echo "  Frontend:      $(GREEN)http://localhost:3017$(NC)"
	@echo "  Backend API:   $(GREEN)http://localhost:8000$(NC)"
	@echo "  API Docs:      $(GREEN)http://localhost:8000/docs$(NC)"
	@echo "  MongoDB:       $(GREEN)mongodb://localhost:27017$(NC)"
	@echo "  Minio Console: $(GREEN)http://localhost:9001$(NC)"
	@echo "  Minio S3 API:  $(GREEN)http://localhost:9002$(NC)"
	@echo "  Whisper (Local): $(GREEN)http://localhost:9000$(NC) $(YELLOW)(run ./scripts/run-whisper-local.sh)$(NC)"
	@echo ""
	@echo "$(BLUE)Lambda Services:$(NC)"
	@echo "  Poll Lambda:     $(GREEN)http://localhost:8001$(NC)"
	@echo "  Chunking Lambda: $(GREEN)http://localhost:8002$(NC)"
	@echo "  Whisper Lambda:  $(GREEN)http://localhost:8003$(NC)"
	@echo "  Merge Lambda:    $(GREEN)http://localhost:8004$(NC)"

down: ## Stop all services
	@echo "$(BLUE)Stopping all services...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart all services
	@echo "$(BLUE)Restarting all services...$(NC)"
	docker-compose restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

logs: ## View logs from all services
	docker-compose logs -f

logs-backend: ## View backend logs
	docker-compose logs -f backend

logs-frontend: ## View frontend logs
	docker-compose logs -f frontend

logs-mongodb: ## View MongoDB logs
	docker-compose logs -f mongodb

logs-minio: ## View Minio logs
	docker-compose logs -f minio

logs-lambdas: ## View all Lambda service logs
	docker-compose logs -f poll-lambda chunking-lambda whisper-lambda merge-lambda

logs-poll: ## View poll-lambda logs
	docker-compose logs -f poll-lambda

logs-chunking: ## View chunking-lambda logs
	docker-compose logs -f chunking-lambda

logs-whisper-lambda: ## View whisper-lambda logs
	docker-compose logs -f whisper-lambda

logs-merge: ## View merge-lambda logs
	docker-compose logs -f merge-lambda

shell-backend: ## Open shell in backend container
	@echo "$(BLUE)Opening shell in backend container...$(NC)"
	docker-compose exec backend /bin/bash

shell-frontend: ## Open shell in frontend container
	@echo "$(BLUE)Opening shell in frontend container...$(NC)"
	docker-compose exec frontend /bin/sh

shell-mongo: ## Open MongoDB shell
	@echo "$(BLUE)Opening MongoDB shell...$(NC)"
	docker-compose exec mongodb mongosh podcast_db

ps: ## Show status of all services
	@echo "$(BLUE)Service Status:$(NC)"
	@docker-compose ps

health: ## Check health of all services
	@echo "$(BLUE)Checking service health...$(NC)"
	@echo ""
	@echo "$(YELLOW)MongoDB:$(NC)"
	@docker-compose exec mongodb mongosh --quiet --eval "db.runCommand('ping')" 2>/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(YELLOW)Minio:$(NC)"
	@curl -sf http://localhost:9002/minio/health/live > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(YELLOW)Whisper (Local):$(NC)"
	@curl -sf http://localhost:9000/ > /dev/null && echo "$(GREEN)✓ Healthy (run ./scripts/run-whisper-local.sh if not running)$(NC)" || echo "$(YELLOW)✗ Not Running - Start with: ./scripts/run-whisper-local.sh$(NC)"
	@echo ""
	@echo "$(YELLOW)Backend API:$(NC)"
	@curl -sf http://localhost:8000/health > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(YELLOW)Frontend:$(NC)"
	@curl -sf http://localhost:3017 > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(YELLOW)Poll Lambda:$(NC)"
	@curl -sf http://localhost:8001/health > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(YELLOW)Chunking Lambda:$(NC)"
	@curl -sf http://localhost:8002/health > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(YELLOW)Whisper Lambda:$(NC)"
	@curl -sf http://localhost:8003/health > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(YELLOW)Merge Lambda:$(NC)"
	@curl -sf http://localhost:8004/health > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"

init-db: ## Initialize MongoDB with schemas and sample data
	@echo "$(BLUE)Initializing MongoDB...$(NC)"
	docker-compose exec backend python scripts/setup_mongodb.py
	@echo "$(GREEN)✓ Database initialized$(NC)"

clean: ## Stop services and remove volumes (WARNING: deletes all data)
	@echo "$(YELLOW)⚠ This will delete all data in MongoDB and Minio$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(BLUE)Cleaning up...$(NC)"; \
		docker-compose down -v; \
		echo "$(GREEN)✓ Cleanup complete$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

rebuild: ## Rebuild all containers from scratch
	@echo "$(BLUE)Rebuilding all containers...$(NC)"
	docker-compose build --no-cache
	@echo "$(GREEN)✓ Rebuild complete$(NC)"

rebuild-backend: ## Rebuild only backend container
	@echo "$(BLUE)Rebuilding backend container...$(NC)"
	docker-compose build --no-cache backend
	docker-compose up -d backend
	@echo "$(GREEN)✓ Backend rebuilt$(NC)"

rebuild-frontend: ## Rebuild only frontend container
	@echo "$(BLUE)Rebuilding frontend container...$(NC)"
	docker-compose build --no-cache frontend
	docker-compose up -d frontend
	@echo "$(GREEN)✓ Frontend rebuilt$(NC)"

rebuild-lambdas: ## Rebuild all Lambda service containers
	@echo "$(BLUE)Rebuilding Lambda containers...$(NC)"
	docker-compose build --no-cache poll-lambda chunking-lambda whisper-lambda merge-lambda
	docker-compose up -d poll-lambda chunking-lambda whisper-lambda merge-lambda
	@echo "$(GREEN)✓ Lambda services rebuilt$(NC)"

install: setup up ## Full installation - setup and start services
	@echo "$(GREEN)✓ Installation complete!$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. Edit .env and add your OPENAI_API_KEY (optional for dev)"
	@echo "  2. Run 'make init-db' to initialize the database"
	@echo "  3. Run 'make dev' to start all services (includes Whisper)"
	@echo "  4. Open http://localhost:3017 in your browser"
	@echo ""
	@echo "$(YELLOW)Note: 'make dev' automatically starts the local Whisper service$(NC)"

start-whisper: ## Start local Whisper service in background
	@echo "$(BLUE)Starting local Whisper service...$(NC)"
	@if lsof -Pi :9000 -sTCP:LISTEN -t >/dev/null 2>&1 ; then \
		echo "$(YELLOW)Whisper service already running on port 9000$(NC)"; \
	else \
		echo "$(GREEN)Starting Whisper service (medium.en model)...$(NC)"; \
		nohup ./scripts/run-whisper-local.sh medium.en > /tmp/whisper-service.log 2>&1 & \
		echo $$! > /tmp/whisper-service.pid; \
		sleep 3; \
		if curl -sf http://localhost:9000/ > /dev/null; then \
			echo "$(GREEN)✓ Whisper service started successfully$(NC)"; \
			echo "$(YELLOW)View logs: tail -f /tmp/whisper-service.log$(NC)"; \
		else \
			echo "$(RED)✗ Failed to start Whisper service$(NC)"; \
			echo "$(YELLOW)Check logs: cat /tmp/whisper-service.log$(NC)"; \
		fi \
	fi

stop-whisper: ## Stop local Whisper service
	@echo "$(BLUE)Stopping local Whisper service...$(NC)"
	@if [ -f /tmp/whisper-service.pid ]; then \
		PID=$$(cat /tmp/whisper-service.pid); \
		if ps -p $$PID > /dev/null 2>&1; then \
			kill $$PID; \
			rm /tmp/whisper-service.pid; \
			echo "$(GREEN)✓ Whisper service stopped$(NC)"; \
		else \
			echo "$(YELLOW)Whisper service not running$(NC)"; \
			rm /tmp/whisper-service.pid; \
		fi \
	else \
		if lsof -Pi :9000 -sTCP:LISTEN -t >/dev/null 2>&1 ; then \
			PID=$$(lsof -Pi :9000 -sTCP:LISTEN -t); \
			kill $$PID; \
			echo "$(GREEN)✓ Whisper service stopped$(NC)"; \
		else \
			echo "$(YELLOW)Whisper service not running$(NC)"; \
		fi \
	fi

dev: start-whisper up logs ## Start Whisper and all services, then follow logs

down-all: down stop-whisper ## Stop all services including Whisper

backup-db: ## Backup MongoDB database
	@echo "$(BLUE)Backing up MongoDB...$(NC)"
	@mkdir -p backups
	docker-compose exec -T mongodb mongodump --db podcast_db --archive > backups/mongodb-backup-$$(date +%Y%m%d-%H%M%S).archive
	@echo "$(GREEN)✓ Backup created in backups/ directory$(NC)"

restore-db: ## Restore MongoDB database (Usage: make restore-db FILE=backups/mongodb-backup-XXXXXXXX.archive)
	@if [ -z "$(FILE)" ]; then \
		echo "$(YELLOW)Usage: make restore-db FILE=backups/mongodb-backup-XXXXXXXX.archive$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring MongoDB from $(FILE)...$(NC)"
	docker-compose exec -T mongodb mongorestore --db podcast_db --archive < $(FILE)
	@echo "$(GREEN)✓ Database restored$(NC)"

lint-backend: ## Run linter on backend code
	@echo "$(BLUE)Running backend linter...$(NC)"
	docker-compose exec backend python -m flake8 app

lint-frontend: ## Run linter on frontend code
	@echo "$(BLUE)Running frontend linter...$(NC)"
	docker-compose exec frontend npm run lint

test-backend: ## Run backend tests
	@echo "$(BLUE)Running backend tests...$(NC)"
	docker-compose exec backend pytest

prune: ## Remove unused Docker resources
	@echo "$(BLUE)Pruning Docker resources...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✓ Prune complete$(NC)"

# =============================================================================
# Minio/S3 Operations
# =============================================================================

s3-list: ## List S3 buckets in Minio
	@echo "$(BLUE)S3 Buckets:$(NC)"
	docker-compose exec minio mc ls myminio/ 2>/dev/null || \
		(docker-compose exec minio mc alias set myminio http://localhost:9002 minioadmin minioadmin && \
		docker-compose exec minio mc ls myminio/)

s3-list-audio: ## List files in podcast-audio bucket
	@echo "$(BLUE)Files in podcast-audio bucket:$(NC)"
	docker-compose exec minio mc ls myminio/podcast-audio --recursive 2>/dev/null || echo "Bucket empty or not found"

s3-list-transcripts: ## List files in podcast-transcripts bucket
	@echo "$(BLUE)Files in podcast-transcripts bucket:$(NC)"
	docker-compose exec minio mc ls myminio/podcast-transcripts --recursive 2>/dev/null || echo "Bucket empty or not found"

# =============================================================================
# Lambda HTTP Service Operations
# =============================================================================

invoke-poll: ## Invoke poll-lambda via HTTP
	@echo "$(BLUE)Invoking poll-lambda...$(NC)"
	curl -X POST http://localhost:8001/invoke -H "Content-Type: application/json" -d '{}' | jq .

invoke-chunking: ## Invoke chunking-lambda via HTTP (requires payload)
	@echo "$(BLUE)Invoking chunking-lambda...$(NC)"
	@echo "$(YELLOW)Usage: curl -X POST http://localhost:8002/invoke -H 'Content-Type: application/json' -d '{\"episode_id\":\"...\",\"audio_url\":\"...\",\"s3_bucket\":\"podcast-audio\"}'$(NC)"

invoke-whisper: ## Invoke whisper-lambda via HTTP (requires payload)
	@echo "$(BLUE)Invoking whisper-lambda...$(NC)"
	@echo "$(YELLOW)Usage: curl -X POST http://localhost:8003/invoke -H 'Content-Type: application/json' -d '{\"episode_id\":\"...\",\"chunk_index\":0,\"s3_key\":\"...\",\"s3_bucket\":\"podcast-audio\"}'$(NC)"

invoke-merge: ## Invoke merge-lambda via HTTP (requires payload)
	@echo "$(BLUE)Invoking merge-lambda...$(NC)"
	@echo "$(YELLOW)Usage: curl -X POST http://localhost:8004/invoke -H 'Content-Type: application/json' -d '{\"episode_id\":\"...\",\"total_chunks\":1,\"transcripts\":[...],\"s3_bucket\":\"podcast-audio\"}'$(NC)"

# =============================================================================
# Transcription Workflow
# =============================================================================

transcribe: ## Start transcription for an episode (Usage: make transcribe EPISODE_ID=xxx)
	@if [ -z "$(EPISODE_ID)" ]; then \
		echo "$(YELLOW)Usage: make transcribe EPISODE_ID=xxx$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Starting transcription for episode $(EPISODE_ID)...$(NC)"
	curl -X POST http://localhost:8000/api/transcription/start \
		-H "Content-Type: application/json" \
		-d '{"episode_id":"$(EPISODE_ID)"}' | jq .

transcribe-status: ## Check transcription status (Usage: make transcribe-status EPISODE_ID=xxx)
	@if [ -z "$(EPISODE_ID)" ]; then \
		echo "$(YELLOW)Usage: make transcribe-status EPISODE_ID=xxx$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Checking transcription status for episode $(EPISODE_ID)...$(NC)"
	curl -s http://localhost:8000/api/transcription/status/$(EPISODE_ID) | jq .

# =============================================================================
# Go Lambda Development (for production AWS deployment)
# =============================================================================

test-go-lambdas: ## Run tests for Go Lambdas
	@echo "$(BLUE)Testing Go Lambdas...$(NC)"
	@echo "$(YELLOW)Running tests for Poll Lambda...$(NC)"
	cd poll-lambda-go && go test -v ./...
	@echo "$(YELLOW)Running tests for Merge Lambda...$(NC)"
	cd merge-transcript-lambda-go && go test -v ./...
	@echo "$(GREEN)✓ Tests complete$(NC)"

go-mod-tidy: ## Run go mod tidy on all Go modules
	@echo "$(BLUE)Running go mod tidy...$(NC)"
	cd poll-lambda-go && go mod tidy
	cd merge-transcript-lambda-go && go mod tidy
	@echo "$(GREEN)✓ Go modules tidied$(NC)"

# =============================================================================
# Legacy Lambda Build Targets (for Terraform AWS deployment)
# =============================================================================

build-lambdas: ## Build all Lambda functions for AWS deployment
	@echo "$(BLUE)Building all Lambda functions for AWS deployment...$(NC)"
	./lambdas/build.sh all
	@echo "$(GREEN)✓ All Lambdas built$(NC)"

build-go-lambdas: ## Build all Go Lambda functions for AWS deployment
	@echo "$(BLUE)Building Go Lambdas...$(NC)"
	./lambdas/build.sh go
	@echo "$(GREEN)✓ Go Lambdas built$(NC)"

build-python-lambdas: ## Build all Python Lambda functions for AWS deployment
	@echo "$(BLUE)Building Python Lambdas...$(NC)"
	./lambdas/build.sh python
	@echo "$(GREEN)✓ Python Lambdas built$(NC)"

clean-lambdas: ## Clean all Lambda build artifacts
	@echo "$(BLUE)Cleaning Lambda artifacts...$(NC)"
	./lambdas/build.sh clean
	@echo "$(GREEN)✓ Lambda artifacts cleaned$(NC)"
