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
	@echo "  Frontend:  $(GREEN)http://localhost:3017$(NC)"
	@echo "  Backend:   $(GREEN)http://localhost:8000$(NC)"
	@echo "  API Docs:  $(GREEN)http://localhost:8000/docs$(NC)"
	@echo "  MongoDB:   $(GREEN)mongodb://localhost:27017$(NC)"
	@echo "  LocalStack: $(GREEN)http://localhost:4566$(NC)"

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

logs-localstack: ## View LocalStack logs
	docker-compose logs -f localstack

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
	@echo "$(YELLOW)Backend API:$(NC)"
	@curl -f http://localhost:8000/health 2>/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(YELLOW)Frontend:$(NC)"
	@curl -f http://localhost:3017 2>/dev/null > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"
	@echo ""
	@echo "$(YELLOW)LocalStack:$(NC)"
	@curl -f http://localhost:4566/_localstack/health 2>/dev/null > /dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(YELLOW)✗ Unhealthy$(NC)"

init-db: ## Initialize MongoDB with schemas and sample data
	@echo "$(BLUE)Initializing MongoDB...$(NC)"
	docker-compose exec backend python scripts/setup_mongodb.py
	@echo "$(GREEN)✓ Database initialized$(NC)"

clean: ## Stop services and remove volumes (WARNING: deletes all data)
	@echo "$(YELLOW)⚠ This will delete all data in MongoDB and LocalStack$(NC)"
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

install: setup up ## Full installation - setup and start services
	@echo "$(GREEN)✓ Installation complete!$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. Edit .env and add your OPENAI_API_KEY"
	@echo "  2. Run 'make init-db' to initialize the database"
	@echo "  3. Open http://localhost:3017 in your browser"

dev: up logs ## Start services and follow logs

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

s3-list: ## List S3 buckets in LocalStack
	@echo "$(BLUE)S3 Buckets:$(NC)"
	docker-compose exec localstack awslocal s3 ls

s3-list-audio: ## List files in podcast-audio bucket
	@echo "$(BLUE)Files in podcast-audio bucket:$(NC)"
	docker-compose exec localstack awslocal s3 ls s3://podcast-audio --recursive

s3-list-transcripts: ## List files in podcast-transcripts bucket
	@echo "$(BLUE)Files in podcast-transcripts bucket:$(NC)"
	docker-compose exec localstack awslocal s3 ls s3://podcast-transcripts --recursive

prune: ## Remove unused Docker resources
	@echo "$(BLUE)Pruning Docker resources...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✓ Prune complete$(NC)"

# Go Lambda build targets
build-go-lambdas: build-poll-lambda-go build-merge-lambda-go ## Build all Go Lambda functions

build-poll-lambda-go: ## Build Poll Lambda (Go) using Docker
	@echo "$(BLUE)Building Poll Lambda (Go) in Docker...$(NC)"
	docker-compose run --rm lambda-builder-poll
	@echo "$(GREEN)✓ Poll Lambda built$(NC)"

build-merge-lambda-go: ## Build Merge Lambda (Go) using Docker
	@echo "$(BLUE)Building Merge Lambda (Go) in Docker...$(NC)"
	docker-compose run --rm lambda-builder-merge
	@echo "$(GREEN)✓ Merge Lambda built$(NC)"

build-chunking-lambda: ## Build Chunking Lambda (Python) using Docker
	@echo "$(BLUE)Building Chunking Lambda (Python) in Docker...$(NC)"
	docker run --rm -v $(PWD)/chunking-lambda:/build/chunking-lambda -w /build/chunking-lambda python:3.11-slim bash -c "chmod +x build-docker.sh && ./build-docker.sh"
	@echo "$(GREEN)✓ Chunking Lambda built$(NC)"

build-whisper-lambda: ## Build Whisper Lambda (Python) using Docker
	@echo "$(BLUE)Building Whisper Lambda (Python) in Docker...$(NC)"
	docker run --rm -v $(PWD)/whisper-lambda:/build/whisper-lambda -w /build/whisper-lambda python:3.11-slim bash -c "chmod +x build-docker.sh && ./build-docker.sh"
	@echo "$(GREEN)✓ Whisper Lambda built$(NC)"

build-all-lambdas: build-poll-lambda-go build-merge-lambda-go build-chunking-lambda build-whisper-lambda ## Build all Lambda functions

clean-lambdas: ## Clean all Lambda build artifacts
	@echo "$(BLUE)Cleaning Lambda artifacts...$(NC)"
	rm -f poll-lambda-go/bootstrap poll-lambda-go/*.zip
	rm -f merge-transcript-lambda-go/bootstrap merge-transcript-lambda-go/*.zip
	rm -f chunking-lambda/*.zip chunking-lambda/package
	rm -f whisper-lambda/*.zip whisper-lambda/package
	@echo "$(GREEN)✓ Lambda artifacts cleaned$(NC)"

clean-go-lambdas: ## Clean Go Lambda build artifacts
	@echo "$(BLUE)Cleaning Go Lambda artifacts...$(NC)"
	rm -f poll-lambda-go/bootstrap poll-lambda-go/*.zip
	rm -f merge-transcript-lambda-go/bootstrap merge-transcript-lambda-go/*.zip
	@echo "$(GREEN)✓ Go Lambda artifacts cleaned$(NC)"

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

deploy-lambdas: build-all-lambdas ## Build and deploy all Lambdas to LocalStack
	@echo "$(BLUE)Deploying all Lambdas to LocalStack...$(NC)"
	docker-compose exec localstack /etc/localstack/init/ready.d/init-lambda.sh
	@echo "$(GREEN)✓ All Lambdas deployed to LocalStack$(NC)"

list-lambdas: ## List all Lambda functions in LocalStack
	@echo "$(BLUE)Lambda functions in LocalStack:$(NC)"
	docker-compose exec localstack awslocal lambda list-functions --query 'Functions[].FunctionName' --output table

invoke-poll-lambda: ## Manually invoke the poll Lambda in LocalStack
	@echo "$(BLUE)Invoking poll-rss-feeds Lambda...$(NC)"
	docker-compose exec localstack awslocal lambda invoke --function-name poll-rss-feeds /tmp/output.json
	@echo "$(GREEN)Response:$(NC)"
	docker-compose exec localstack cat /tmp/output.json | jq .
	@echo ""

invoke-chunking-lambda: ## Manually invoke the chunking Lambda in LocalStack
	@echo "$(BLUE)Invoking chunking-lambda...$(NC)"
	@echo '{"episode_id":"test123","audio_url":"https://example.com/audio.mp3","s3_bucket":"podcast-audio"}' | \
	docker-compose exec -T localstack awslocal lambda invoke --function-name chunking-lambda --payload file:///dev/stdin /tmp/output.json
	@echo "$(GREEN)Response:$(NC)"
	docker-compose exec localstack cat /tmp/output.json | jq .

invoke-whisper-lambda: ## Manually invoke the whisper Lambda in LocalStack
	@echo "$(BLUE)Invoking whisper-lambda...$(NC)"
	@echo '{"s3_bucket":"podcast-audio","s3_key":"test/chunk.mp3"}' | \
	docker-compose exec -T localstack awslocal lambda invoke --function-name whisper-lambda --payload file:///dev/stdin /tmp/output.json
	@echo "$(GREEN)Response:$(NC)"
	docker-compose exec localstack cat /tmp/output.json | jq .

invoke-merge-lambda: ## Manually invoke the merge transcript Lambda in LocalStack
	@echo "$(BLUE)Invoking merge-transcript Lambda...$(NC)"
	@echo '{"episode_id":"test123","chunks":[{"index":0,"s3_key":"test/chunk0.txt"}]}' | \
	docker-compose exec -T localstack awslocal lambda invoke --function-name merge-transcript --payload file:///dev/stdin /tmp/output.json
	@echo "$(GREEN)Response:$(NC)"
	docker-compose exec localstack cat /tmp/output.json | jq .
