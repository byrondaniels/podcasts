# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A full-stack podcast management application that automatically transcribes podcast episodes using AWS Lambda functions orchestrated by Step Functions. The system polls RSS feeds, downloads audio, chunks files for processing, transcribes via OpenAI Whisper, and merges results into complete transcripts.

## Architecture

### Development Environment (Docker Compose)
- **Frontend**: React 18 + TypeScript + Vite (port 3000)
- **Backend**: Python FastAPI server (port 8000)
- **MongoDB**: Document database (port 27017)
- **LocalStack**: AWS service emulation - S3, Lambda, Step Functions (port 4566)
- **Whisper Service**: Local ASR service for development (port 9000)

### Production Environment (AWS via Terraform)
- **S3 Buckets**: `podcast-audio` (raw audio, chunks), `podcast-transcripts` (final transcripts)
- **Lambda Functions**:
  - `poll-lambda-go`: Polls RSS feeds every 30 mins (Go)
  - `chunking-lambda`: Splits audio into 10-min chunks (Python)
  - `whisper-lambda`: Transcribes chunks via Whisper API (Python)
  - `merge-transcript-lambda-go`: Combines chunk transcripts (Go)
- **Step Functions**: Orchestrates DownloadAndChunk → TranscribeChunks (Map, max 10 concurrent) → MergeTranscripts
- **EventBridge**: Triggers RSS poller on schedule
- **SSM Parameter Store**: Stores MongoDB URI and OpenAI API key

### Data Flow
1. RSS poller discovers new episodes → creates episode records in MongoDB
2. Step Function triggered with episode_id
3. Audio downloaded and chunked to S3
4. Parallel transcription of chunks (max 10 concurrent)
5. Chunks merged into final transcript and stored in S3
6. Episode status updated: pending → processing → completed/failed

## Development Commands

### Initial Setup
```bash
make setup              # Copy .env.example to .env (then edit OPENAI_API_KEY)
make up                 # Start all Docker services
make init-db            # Initialize MongoDB schemas and indexes
```

### Daily Development
```bash
make dev                # Start services and follow logs
make logs               # View all service logs
make logs-backend       # View backend logs only
make logs-frontend      # View frontend logs only
make ps                 # Show service status
make health             # Check health of all services
```

### Database Operations
```bash
make shell-mongo        # Open MongoDB shell (db: podcast_db)
make backup-db          # Backup MongoDB to backups/ directory
make restore-db FILE=backups/mongodb-backup-XXXXXXXX.archive
make init-db            # Re-run schema setup
```

### Container Management
```bash
make shell-backend      # Open bash in backend container
make shell-frontend     # Open shell in frontend container
make restart            # Restart all services
make down               # Stop all services
make clean              # Stop and delete volumes (WARNING: deletes data)
make rebuild            # Rebuild all containers from scratch
```

### LocalStack/S3 Operations
```bash
make s3-list            # List all S3 buckets
make s3-list-audio      # List files in podcast-audio bucket
make s3-list-transcripts # List files in podcast-transcripts bucket
```

### Go Lambda Development
```bash
make build-go-lambdas   # Build all Go Lambdas (poll + merge)
make build-poll-lambda-go    # Build poll Lambda only
make build-merge-lambda-go   # Build merge Lambda only
make test-go-lambdas    # Run tests for Go Lambdas
make clean-go-lambdas   # Clean build artifacts
make go-mod-tidy        # Run go mod tidy on all Go modules
```

### Testing and Linting
```bash
make test-backend       # Run pytest in backend container
make lint-backend       # Run flake8 on backend Python code
make lint-frontend      # Run ESLint on frontend TypeScript code
```

### Frontend (without Docker)
```bash
npm install
npm run dev             # Start Vite dev server
npm run build           # Build for production (TypeScript + Vite)
npm run preview         # Preview production build
npm run lint            # Run ESLint
```

### Backend (without Docker)
```bash
cd server
pip install -r requirements.txt
python -m app.main      # Start FastAPI with auto-reload
# or
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Terraform Deployment
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars  # Edit with MongoDB URI and OpenAI key
terraform init
terraform plan
terraform apply
terraform destroy       # WARNING: Deletes all AWS resources
```

## Key Architecture Details

### MongoDB Collections
- **podcasts**: `podcast_id` (unique), `rss_url`, `title`, `description`, `image_url`, `author`, `subscribed_at`, `active`
- **episodes**: `episode_id` (unique), `podcast_id` (FK), `title`, `audio_url`, `published_date`, `duration_minutes`, `transcript_status` (pending/processing/completed/failed), `transcript_s3_key`, `s3_audio_key`

### API Endpoints

**Production API:**
- `POST /api/podcasts/subscribe` - Subscribe to RSS feed
- `GET /api/podcasts` - List all subscribed podcasts
- `DELETE /api/podcasts/{podcast_id}` - Unsubscribe
- `GET /api/episodes?status=completed&page=1&limit=20` - List episodes with filtering/pagination
- `GET /api/episodes/{episode_id}/transcript` - Get transcript from S3

**Dev/Testing API:**
- `POST /api/dev/bulk-transcribe` - Start bulk transcription job for entire RSS feed
- `GET /api/dev/bulk-transcribe` - List all bulk transcription jobs
- `GET /api/dev/bulk-transcribe/{job_id}` - Get job status and progress
- `POST /api/dev/bulk-transcribe/{job_id}/cancel` - Cancel running job

**Utility:**
- `GET /health` - Health check
- `GET /docs` - Swagger UI

### Step Functions State Machine
Located in `terraform/modules/step-functions/state-machine-definition.json`:
- **DownloadAndChunk**: Downloads audio and splits into chunks (timeout: 15 min)
- **PrepareForMapping**: Prepares chunk array for parallel processing
- **TranscribeChunks**: Map state with max 10 concurrent executions
- **MergeTranscripts**: Combines chunks into final transcript (timeout: 5 min)
- **Error Handling**: 3 retries with exponential backoff, catches all errors

### Environment Variables (.env)
Required:
- `OPENAI_API_KEY` - For Whisper API transcription

Optional (have defaults):
- `VITE_API_URL` - Frontend API URL (default: http://localhost:8000)
- `MONGODB_URL` - MongoDB connection string (default: mongodb://localhost:27017)
- `MONGODB_DB_NAME` - Database name (default: podcast_db)
- `S3_BUCKET_NAME` - S3 bucket for audio (default: podcast-audio)
- `LOG_LEVEL` - Logging level (default: INFO)
- `AWS_ENDPOINT_URL` - LocalStack endpoint (default: http://localstack:4566)

### Testing
- **Go Lambda tests**: Located in `*-lambda-go/*_test.go`
- **Backend tests**: Run via `pytest` in `server/` directory
- **Frontend linting**: ESLint for TypeScript/React

### Important Notes
1. **Backend**: Python FastAPI backend serves both the production API and dev bulk transcribe endpoints.
2. **Lambda Languages**: RSS poller and merge Lambda are Go; chunking and Whisper Lambdas are Python.
3. **Dual Environments**: LocalStack for local dev, real AWS services for production via Terraform.
4. **S3 Lifecycle**: Audio chunks auto-delete after 7 days to save storage costs.
5. **Concurrency Limits**: Whisper Lambda has reserved concurrency of 10 to manage OpenAI API rate limits.
6. **Secrets Management**: Local dev uses .env file; production uses SSM Parameter Store (never env vars).
7. **Bulk Transcribe**: Dev-only feature at `/api/dev/bulk-transcribe` for testing full podcast transcription locally.

### Code Structure
```
podcasts/
├── src/                          # React frontend
│   ├── components/               # React components (Subscription, Transcripts, Modal)
│   ├── services/                 # API client services
│   └── types/                    # TypeScript type definitions
├── server/                       # Python FastAPI backend
│   └── app/
│       ├── routes/               # API endpoints (podcasts, episodes, dev bulk transcribe)
│       ├── services/             # Business logic (RSS parser, S3, Whisper, bulk transcribe)
│       ├── models/               # Pydantic schemas
│       └── database/             # MongoDB connection
├── poll-lambda-go/               # RSS polling Lambda (Go)
├── merge-transcript-lambda-go/   # Transcript merging Lambda (Go)
├── chunking-lambda/              # Audio chunking Lambda (Python)
├── whisper-lambda/               # Transcription Lambda (Python)
└── terraform/                    # Infrastructure as Code
    └── modules/                  # Reusable Terraform modules (s3, lambda, step-functions, ssm)
```

### Working with this Codebase
- When modifying Go Lambdas, run `make build-go-lambdas` and `make test-go-lambdas` before committing.
- The backend has hot-reload enabled in Docker, so Python/Go changes reflect immediately.
- Frontend has Vite HMR, so React changes appear without refresh.
- MongoDB indexes are auto-created on backend startup.
- LocalStack state persists in Docker volumes; use `make clean` to reset.
- For production deployments, always run `terraform plan` before `terraform apply`.
