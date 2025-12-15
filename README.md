# Podcast Manager

A modern React application for managing podcast subscriptions and viewing episode transcripts. Built with TypeScript, React hooks, and a clean, responsive UI.

## Features

### Podcast Subscriptions
- **Subscribe to Podcasts**: Add podcasts using their RSS feed URLs
- **Episode Discovery**: Automatically discovers and displays episode count on subscription
- **View Subscriptions**: Display all subscribed podcasts with title, description, thumbnail, and episode count
- **Navigate to Episodes**: Click podcast cards to view all episodes for that podcast
- **Unsubscribe**: Remove podcasts from your subscription list
- **Form Validation**: Real-time validation for RSS feed URLs
- **Automatic Polling**: RSS feeds are checked every 30 minutes for new episodes (limited to 10 most recent)

### Episode Transcripts
- **Browse Episodes**: View episodes from all subscribed podcasts in list view
- **Dual Filters**: Filter by transcript status (All, Completed, Processing, Failed) AND by podcast
- **URL-Based Filtering**: Podcast filter persists in URL for bookmarking (e.g., `/transcripts?podcast=xyz`)
- **View Transcripts**: Read full episode transcripts in a modal viewer
- **Copy to Clipboard**: Easily copy transcript text for external use
- **Status Indicators**: Visual badges showing transcript processing status (pending, processing, completed, failed)
- **Episode Metadata**: Display published date, duration, podcast name, and episode title

### Bulk Transcribe (Development Feature)
- **Batch Processing**: Transcribe entire podcast feeds at once
- **Job Management**: Create, monitor, and cancel bulk transcription jobs
- **Progress Tracking**: Real-time progress updates with completed/total counts
- **Job History**: View all bulk transcription jobs with status and timestamps

### Common Features
- **React Router**: Separate URLs for subscriptions, transcripts, and bulk transcribe
- **Loading States**: Skeleton loaders and spinners during API calls
- **Error Handling**: User-friendly error messages with retry options
- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices
- **Hot Reload**: Instant frontend updates and automatic backend reloads during development

## Tech Stack

### Frontend
- **React 18** with TypeScript
- **Vite** for fast development and building
- **CSS3** with modern responsive design

### Backend
- **FastAPI** - Modern Python web framework
- **Motor** - Async MongoDB driver
- **Uvicorn** - ASGI server

### Database & Storage
- **MongoDB 7** - Document database
- **LocalStack** - AWS service emulation (S3, Lambda, Step Functions)

### Development
- **Docker & Docker Compose** - Containerized development environment

## 🚀 Quick Start - Run Locally

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (version 20.10 or higher)
- [Docker Compose](https://docs.docker.com/compose/install/) (version 2.0 or higher)
- Make (optional, but recommended)

**Note**: You do NOT need Go, Python, or Node.js installed locally. Everything runs in Docker containers.

### Step-by-Step Setup

#### 1. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd podcasts

# Set up environment variables
make setup
# This copies .env.example to .env

# Edit .env and add your OpenAI API key
# Open .env in your editor and set:
# OPENAI_API_KEY=sk-your-actual-api-key-here
```

#### 2. Build Lambda Functions

The application uses 4 Lambda functions that need to be built before starting:

```bash
# Build all Lambda functions (Go and Python)
make build-all-lambdas

# This builds:
# - poll-lambda-go (RSS feed polling)
# - merge-transcript-lambda-go (transcript merging)
# - chunking-lambda (audio chunking)
# - whisper-lambda (audio transcription)
```

**What happens during build:**
- Go Lambdas are compiled in `golang:1.21-alpine` containers
- Python Lambdas are packaged with dependencies in Lambda runtime containers
- No local Go or Python installation required
- Build artifacts are placed in their respective Lambda directories

#### 3. Start All Services

```bash
# Start all Docker services
make up

# This starts:
# - MongoDB (port 27017)
# - LocalStack (port 4566) - AWS emulation
# - Whisper Service (port 9000) - local transcription
# - Backend API (port 8000)
# - Frontend (port 3017)
```

#### 4. Initialize the Database

```bash
# First time setup - create MongoDB indexes and schemas
make init-db
```

#### 5. Deploy Lambda Functions to LocalStack

```bash
# Deploy all Lambda functions to LocalStack
make deploy-lambdas

# This deploys all 4 Lambdas and sets up:
# - S3 buckets (podcast-audio, podcast-transcripts)
# - Lambda functions in LocalStack
# - EventBridge rule for automatic polling every 30 minutes
# - Step Functions state machine
```

#### 6. Access the Application

Open your browser to:
- **Frontend**: http://localhost:3017
- **Backend API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **LocalStack**: http://localhost:4566

### Quick Start (All-in-One)

If you want to get everything running quickly:

```bash
# One-time setup
make setup                    # Create .env file
# Edit .env and add OPENAI_API_KEY
make build-all-lambdas        # Build Lambda functions
make up                       # Start all services
make init-db                  # Initialize database
make deploy-lambdas           # Deploy Lambdas to LocalStack

# Daily development
make dev                      # Start services and follow logs
```

### Triggering Transcription

The application automatically polls RSS feeds every 30 minutes, but you can manually trigger it:

```bash
# Manually invoke the RSS poller Lambda
make invoke-poll-lambda

# This will:
# 1. Check all subscribed podcasts for new episodes
# 2. Download the 10 most recent episodes
# 3. Trigger transcription workflow for each episode
```

### Makefile Commands

The project includes a comprehensive Makefile for easy management:

#### Core Commands
```bash
make help              # Show all available commands
make setup             # Initial setup - copy .env.example to .env
make up                # Start all services
make down              # Stop all services
make restart           # Restart all services
make dev               # Start services and follow logs
```

#### Service Management
```bash
make ps                # Show status of all services
make health            # Check health of all services
make logs              # View logs from all services
make logs-backend      # View backend logs only
make logs-frontend     # View frontend logs only
make logs-mongodb      # View MongoDB logs only
make logs-localstack   # View LocalStack logs only
```

#### Database Operations
```bash
make init-db           # Initialize MongoDB with schemas and indexes
make shell-mongo       # Open MongoDB shell
make backup-db         # Backup MongoDB database
make restore-db        # Restore MongoDB database (specify FILE=...)
```

#### Lambda Development
```bash
# Build Lambda functions
make build-all-lambdas      # Build all Lambda functions
make build-poll-lambda-go   # Build RSS polling Lambda
make build-merge-lambda-go  # Build transcript merging Lambda
make build-chunking-lambda  # Build audio chunking Lambda
make build-whisper-lambda   # Build transcription Lambda

# Deploy and invoke
make deploy-lambdas         # Deploy all Lambdas to LocalStack
make list-lambdas           # List all Lambda functions
make invoke-poll-lambda     # Manually trigger RSS polling
make invoke-chunking-lambda # Test chunking Lambda
make invoke-whisper-lambda  # Test transcription Lambda
make invoke-merge-lambda    # Test merge Lambda

# Cleanup
make clean-lambdas          # Clean all Lambda build artifacts
make clean-go-lambdas       # Clean only Go Lambda artifacts
```

#### LocalStack / S3 Operations
```bash
make s3-list               # List S3 buckets in LocalStack
make s3-list-audio         # List files in podcast-audio bucket
make s3-list-transcripts   # List files in podcast-transcripts bucket
```

#### Container Management
```bash
make shell-backend     # Open shell in backend container
make shell-frontend    # Open shell in frontend container
make rebuild           # Rebuild all containers from scratch
make rebuild-backend   # Rebuild only backend container
make rebuild-frontend  # Rebuild only frontend container
```

#### Testing & Linting
```bash
make test-backend      # Run backend tests
make test-go-lambdas   # Run tests for Go Lambda functions
make lint-backend      # Run Python linter on backend
make lint-frontend     # Run ESLint on frontend
```

#### Cleanup
```bash
make clean             # Stop services and remove volumes (WARNING: deletes data)
make prune             # Remove unused Docker resources
```

## 🐳 Docker Architecture

### Services

#### 1. MongoDB
- **Image**: mongo:7
- **Port**: 27017
- **Purpose**: Primary database for podcasts and episodes
- **Volume**: `mongodb-data` for persistence
- **Initialization**: Automatic schema and index creation
- **Health Check**: MongoDB ping command

#### 2. LocalStack (AWS Emulation)
- **Image**: localstack/localstack:latest
- **Port**: 4566 (main), 4510-4559 (services)
- **Services**: S3, Lambda, Step Functions, EventBridge
- **Purpose**: Local AWS service emulation for development
- **Volume**: `localstack-data` for persistence
- **Auto-init**: Deploys Lambda functions and creates S3 buckets on startup
- **Dependencies**: MongoDB (for Lambda connection)

#### 3. Whisper Service (Dev Only)
- **Image**: onerahmet/openai-whisper-asr-webservice:latest
- **Port**: 9000
- **Purpose**: Local Whisper ASR for development transcription
- **Model**: base (configurable)
- **Volume**: `whisper-models` for model caching
- **Note**: In production, whisper-lambda uses OpenAI Whisper API

#### 4. Backend (FastAPI)
- **Build**: `./server/Dockerfile`
- **Port**: 8000
- **Hot Reload**: Enabled via volume mounts (`./server/app`, `./server/scripts`)
- **Health Check**: `/health` endpoint
- **Dependencies**: MongoDB, Whisper Service
- **API Docs**: Available at `/docs` (Swagger UI)

#### 5. Frontend (React + Vite)
- **Build**: `./Dockerfile`
- **Port**: 3017
- **Hot Reload**: Enabled via volume mounts (`./src`, `./public`)
- **Health Check**: HTTP on port 3017
- **Dependencies**: Backend API
- **Dev Features**: Vite HMR (Hot Module Replacement)

#### 6. Lambda Builders (Build-Only Services)

These services only run during `make build-*-lambda` commands:

**Go Lambda Builder (Poll & Merge)**
- **Image**: golang:1.21-alpine
- **Purpose**: Compiles Go Lambda functions for AWS Lambda runtime
- **Volumes**: Mounts individual Lambda directories
- **Output**: `bootstrap` binary (Lambda custom runtime)
- **Command**: Runs `build-docker.sh` script in each Lambda directory

**Python Lambda Builder (Chunking & Whisper)**
- **Image**: public.ecr.aws/lambda/python:3.11
- **Purpose**: Packages Python Lambda functions with dependencies
- **Volumes**: Mounts Lambda directories
- **Output**: `.zip` deployment packages
- **Command**: Runs `build-docker.sh` script in each Lambda directory

### Networking

All services run on a shared Docker network (`podcast-network`), allowing them to communicate using service names:
- Backend connects to MongoDB at `mongodb://mongodb:27017`
- Backend connects to LocalStack at `http://localstack:4566`
- Backend connects to Whisper at `http://whisper:9000`
- Frontend connects to Backend at `http://backend:8000` (internally)
- Frontend browser connects to Backend at `http://localhost:8000` (externally)
- Lambda functions connect to MongoDB at `mongodb://mongodb:27017/podcast_db`

### Data Persistence

Three named volumes ensure data persists across container restarts:
- `podcast-mongodb-data`: MongoDB database files
- `podcast-localstack-data`: LocalStack state, S3 objects, and Lambda deployments
- `podcast-whisper-models`: Whisper AI models (cached to avoid re-downloading)

## 🔄 Local Development Workflow

### Complete End-to-End Local Testing

Here's how to test the entire podcast transcription workflow locally:

#### 1. Subscribe to a Podcast

```bash
# Start services if not already running
make dev

# Open browser to http://localhost:3017
# Navigate to "Subscriptions" tab
# Enter an RSS feed URL (e.g., a podcast RSS feed)
# Click "Subscribe"
```

The system will:
- Parse the RSS feed
- Store podcast metadata in MongoDB
- Display the podcast with episode count

#### 2. Trigger Episode Discovery

```bash
# Manually invoke the RSS poller Lambda
make invoke-poll-lambda

# Watch the logs to see what happens
make logs-backend
make logs-localstack
```

The poll Lambda will:
- Fetch all subscribed podcasts from MongoDB
- Parse RSS feeds for new episodes
- Limit to 10 most recent episodes per podcast
- Create episode records in MongoDB with `transcript_status: "pending"`
- Trigger Step Functions for transcription (if configured)

#### 3. View Episodes

```bash
# Refresh the browser
# Navigate to "Transcripts" tab
# You should see episodes listed with status badges
```

Filter episodes by:
- **Status**: All, Completed, Processing, Failed
- **Podcast**: Select a specific podcast to view only its episodes

#### 4. Monitor Transcription Progress

In local development, the transcription workflow happens via Lambda functions in LocalStack:

```bash
# Check Lambda functions are deployed
make list-lambdas

# View LocalStack logs to see Lambda invocations
make logs-localstack

# Check S3 buckets for audio files and transcripts
make s3-list-audio
make s3-list-transcripts
```

The transcription workflow:
1. **Chunking Lambda**: Downloads audio and splits into 10-minute chunks
2. **Whisper Lambda**: Transcribes each chunk in parallel (max 10 concurrent)
3. **Merge Lambda**: Combines chunk transcripts into final transcript

#### 5. View Completed Transcripts

Once transcription completes:
- Episode status changes to `"completed"`
- Transcript stored in S3 and MongoDB
- "View Transcript" button appears in UI
- Click to open transcript in modal
- Copy transcript text to clipboard

### Daily Development Commands

```bash
# Morning startup
make up                    # Start all services
make logs-backend          # Watch backend logs in one terminal
make logs-localstack       # Watch LocalStack logs in another terminal

# Make code changes (hot reload enabled)
# Edit files in:
#   - src/               → Frontend reloads automatically
#   - server/app/        → Backend reloads automatically
#   - *-lambda*/         → Need to rebuild: make build-all-lambdas

# Test Lambda changes
make build-all-lambdas     # Rebuild Lambda functions
make deploy-lambdas        # Deploy to LocalStack
make invoke-poll-lambda    # Test the poller

# Check health
make health                # Check all services are healthy
make ps                    # Show service status

# Database operations
make shell-mongo           # Explore MongoDB data
make backup-db             # Backup before risky changes

# End of day
make down                  # Stop all services (data persists in volumes)
```

### Testing Individual Lambda Functions

```bash
# Test RSS Polling Lambda
make invoke-poll-lambda

# Test Chunking Lambda (requires episode_id)
make invoke-chunking-lambda

# Test Whisper Transcription Lambda
make invoke-whisper-lambda

# Test Merge Transcript Lambda
make invoke-merge-lambda

# View all Lambda functions
make list-lambdas

# Check Lambda logs in LocalStack
docker-compose exec localstack awslocal logs tail /aws/lambda/poll-rss-feeds
```

### Debugging Tips

#### Backend API Issues
```bash
# View backend logs
make logs-backend

# Open backend shell to inspect
make shell-backend
python -c "from app.database import database; print(database.client.server_info())"

# Test API directly
curl http://localhost:8000/health
curl http://localhost:8000/api/podcasts
```

#### Frontend Issues
```bash
# View frontend logs
make logs-frontend

# Check browser console for errors
# Open DevTools → Console

# Verify API connection
curl http://localhost:8000/api/podcasts
```

#### Lambda Issues
```bash
# Check Lambda is deployed
make list-lambdas

# View LocalStack logs
make logs-localstack

# Test Lambda invocation
make invoke-poll-lambda

# Check S3 buckets exist
make s3-list

# View Lambda function details
docker-compose exec localstack awslocal lambda get-function --function-name poll-rss-feeds
```

#### MongoDB Issues
```bash
# Open MongoDB shell
make shell-mongo

# Check databases
show dbs

# Check collections
use podcast_db
show collections

# Query data
db.podcasts.find().pretty()
db.episodes.find().pretty()
```

### Code Changes and Hot Reload

**Frontend (Instant Reload):**
- Edit any file in `src/`
- Browser automatically reloads with changes
- No restart needed

**Backend (Automatic Reload):**
- Edit any file in `server/app/`
- Uvicorn detects changes and reloads
- Check `make logs-backend` to see reload message

**Lambda Functions (Manual Rebuild):**
- Edit files in `*-lambda*/` directories
- Run `make build-all-lambdas` to rebuild
- Run `make deploy-lambdas` to redeploy to LocalStack
- Lambda code is NOT hot-reloaded

**Docker Configuration Changes:**
- Edit `docker-compose.yml` or `Dockerfile`
- Run `make rebuild` to rebuild containers
- Run `make up` to start with new configuration

## 📁 Project Structure

```
podcasts/
├── docker-compose.yml              # Docker Compose configuration
├── Dockerfile                      # Frontend container definition
├── Makefile                        # Development commands
├── .env.example                    # Environment variable template
├── .dockerignore                   # Docker build exclusions
│
├── src/                            # Frontend source code
│   ├── components/
│   │   ├── PodcastSubscription.tsx      # Podcast subscription component
│   │   ├── PodcastSubscription.css      # Subscription component styles
│   │   ├── EpisodeTranscripts.tsx       # Episode transcripts component
│   │   ├── EpisodeTranscripts.css       # Transcripts component styles
│   │   ├── TranscriptModal.tsx          # Modal for viewing transcripts
│   │   └── TranscriptModal.css          # Modal styles
│   ├── services/
│   │   ├── podcastService.ts            # Podcast API service
│   │   └── episodeService.ts            # Episode API service
│   ├── types/
│   │   ├── podcast.ts                   # Podcast type definitions
│   │   └── episode.ts                   # Episode type definitions
│   ├── App.tsx                          # Root component with navigation
│   ├── App.css                          # App and navigation styles
│   ├── main.tsx                         # Entry point
│   └── index.css                        # Global styles
│
├── server/                         # Backend source code
│   ├── Dockerfile                       # Backend container definition
│   ├── .dockerignore                    # Backend build exclusions
│   ├── requirements.txt                 # Python dependencies
│   ├── app/
│   │   ├── main.py                      # FastAPI application
│   │   ├── config.py                    # Configuration management
│   │   ├── database.py                  # MongoDB connection
│   │   ├── models/                      # Pydantic models
│   │   └── routes/                      # API endpoints
│   └── scripts/
│       └── setup_mongodb.py             # Database initialization
│
├── localstack-init/                # LocalStack initialization
│   └── ready.d/
│       └── init-aws.sh                  # S3 bucket creation script
│
├── *-lambda*/                      # Lambda functions
│   ├── poll-lambda-go/                  # RSS feed polling (Go)
│   ├── chunking-lambda/                 # Audio chunking (Python)
│   ├── whisper-lambda/                  # Transcription (Python)
│   └── merge-transcript-lambda-go/      # Transcript merging (Go)
│
├── index.html                      # HTML template
├── package.json                    # Frontend dependencies
├── tsconfig.json                   # TypeScript config
└── vite.config.ts                  # Vite config
```

## 🛠️ Development

### Running Without Docker

If you prefer to run services locally without Docker:

#### Frontend
```bash
npm install
npm run dev
```

#### Backend
```bash
cd server
pip install -r requirements.txt
python -m app.main
```

#### MongoDB
```bash
# Install MongoDB locally and start it
mongod --dbpath /path/to/data
```

### Environment Variables

See `.env.example` for all available configuration options:

- `VITE_API_URL`: Frontend API endpoint
- `MONGODB_URL`: MongoDB connection string
- `AWS_ENDPOINT_URL`: LocalStack endpoint
- `OPENAI_API_KEY`: OpenAI API key for transcription
- `S3_BUCKET_NAME`: S3 bucket for audio files
- `LOG_LEVEL`: Logging verbosity

### Hot Reload

Both frontend and backend support hot reload in development:
- **Frontend**: Vite watches for file changes in `src/`
- **Backend**: Uvicorn watches for file changes in `app/`

Changes to source files are automatically reflected without restarting containers.

### Database Management

#### View MongoDB Data
```bash
make shell-mongo
# or
docker-compose exec mongodb mongosh podcast_db
```

#### Reset Database
```bash
make clean
make up
make init-db
```

#### Backup Database
```bash
make backup-db
```

#### Restore Database
```bash
make restore-db FILE=backups/mongodb-backup-XXXXXXXX.archive
```

### Working with LocalStack

#### List S3 Buckets
```bash
make s3-list
```

#### List Files in Buckets
```bash
make s3-list-audio
make s3-list-transcripts
```

#### Access LocalStack Directly
```bash
docker-compose exec localstack awslocal s3 ls
docker-compose exec localstack awslocal lambda list-functions
```

### Debugging

#### View Logs
```bash
# All services
make logs

# Specific service
make logs-backend
make logs-frontend
make logs-mongodb
make logs-localstack
```

#### Check Service Health
```bash
make health
```

#### Access Container Shell
```bash
make shell-backend
make shell-frontend
```

## 🧪 Testing

### Backend Tests
```bash
make test-backend
# or
docker-compose exec backend pytest
```

### Linting
```bash
make lint-backend
make lint-frontend
```

## 📋 API Endpoints

The application expects the following API endpoints:

### Podcast Endpoints

#### Subscribe to Podcast
```
POST /api/podcasts/subscribe
Content-Type: application/json

Request Body:
{
  "rss_url": "https://example.com/feed.xml"
}

Response:
{
  "podcast_id": "abc123",
  "title": "Podcast Name",
  "status": "subscribed"
}
```

#### Get All Podcasts
```
GET /api/podcasts

Response:
{
  "podcasts": [
    {
      "podcast_id": "abc123",
      "title": "Podcast Title",
      "description": "Podcast description",
      "image_url": "https://example.com/image.jpg",
      "rss_url": "https://example.com/feed.xml"
    }
  ]
}
```

#### Unsubscribe from Podcast
```
DELETE /api/podcasts/{podcast_id}

Response: 204 No Content or 200 OK
```

### Episode Endpoints

#### Get Episodes
```
GET /api/episodes?status=completed&page=1&limit=20

Query Parameters:
- status (optional): Filter by transcript status ("completed", "processing", "failed")
- page (optional): Page number (default: 1)
- limit (optional): Items per page (default: 20)

Response:
{
  "episodes": [
    {
      "episode_id": "ep123",
      "podcast_id": "abc123",
      "podcast_title": "Podcast Name",
      "episode_title": "Episode Title",
      "published_date": "2025-11-16T10:00:00Z",
      "duration_minutes": 45,
      "transcript_status": "completed",
      "transcript_s3_key": "transcripts/ep123.txt"
    }
  ],
  "total": 150,
  "page": 1,
  "limit": 20,
  "totalPages": 8
}
```

#### Get Episode Transcript
```
GET /api/episodes/{episode_id}/transcript

Response:
{
  "transcript": "Full transcript text here..."
}
```

## 🔧 Troubleshooting

### Services Won't Start

```bash
# Check Docker is running
docker --version
docker-compose --version

# Check service status
make ps

# View logs for errors
make logs

# Check for port conflicts
lsof -i :3017    # Frontend
lsof -i :8000    # Backend
lsof -i :27017   # MongoDB
lsof -i :4566    # LocalStack
lsof -i :9000    # Whisper
```

**Common Issues:**
- **Docker not running**: Start Docker Desktop or Docker daemon
- **Port conflicts**: Stop conflicting services or change ports in `docker-compose.yml`
- **Insufficient memory**: Docker needs at least 4GB RAM (8GB recommended)
- **Volume permission issues**: Try `make clean` then `make up`

### Lambda Build Failures

```bash
# Error: "No such file or directory: build-docker.sh"
# Fix: Ensure build scripts are executable
chmod +x poll-lambda-go/build-docker.sh
chmod +x merge-transcript-lambda-go/build-docker.sh
chmod +x chunking-lambda/build-docker.sh
chmod +x whisper-lambda/build-docker.sh

# Error: "go.mod not found"
# Fix: Run go mod tidy
make go-mod-tidy

# Error: "pip install failed"
# Fix: Check requirements.txt exists in Lambda directory
ls -la chunking-lambda/requirements.txt
ls -la whisper-lambda/requirements.txt

# Clean and rebuild all Lambdas
make clean-lambdas
make build-all-lambdas
```

### Lambda Deployment Issues

```bash
# Check LocalStack is running
make health

# Check Lambda functions are deployed
make list-lambdas

# View LocalStack logs for deployment errors
make logs-localstack

# Redeploy Lambdas
make deploy-lambdas

# If Lambdas already exist, delete and recreate
docker-compose exec localstack awslocal lambda delete-function --function-name poll-rss-feeds
docker-compose exec localstack awslocal lambda delete-function --function-name chunking-lambda
docker-compose exec localstack awslocal lambda delete-function --function-name whisper-lambda
docker-compose exec localstack awslocal lambda delete-function --function-name merge-transcript
make deploy-lambdas
```

### Port Conflicts

If ports are already in use, you have two options:

**Option 1: Stop conflicting services**
```bash
# Find what's using the port
lsof -i :3017

# Kill the process
kill -9 <PID>
```

**Option 2: Change ports in docker-compose.yml**
```yaml
# Example: Change frontend from 3017 to 3018
frontend:
  ports:
    - "3018:3017"
```

### Database Connection Issues

```bash
# Check MongoDB is running and healthy
make health

# Try connecting to MongoDB shell
make shell-mongo

# If connection fails, restart MongoDB
docker-compose restart mongodb

# Check MongoDB logs
make logs-mongodb

# Reinitialize database
make init-db

# If still failing, clean volumes and restart
make clean
make up
make init-db
```

### LocalStack Issues

```bash
# Check LocalStack health
curl http://localhost:4566/_localstack/health

# View LocalStack logs
make logs-localstack

# Check if S3 buckets exist
make s3-list

# Recreate S3 buckets manually
docker-compose exec localstack awslocal s3 mb s3://podcast-audio
docker-compose exec localstack awslocal s3 mb s3://podcast-transcripts

# Restart LocalStack
docker-compose restart localstack

# Check Lambda functions
make list-lambdas
```

### Frontend Issues

**Issue: Module not found errors**
```bash
# Rebuild frontend container after npm install
make rebuild-frontend

# Or restart containers
make down
make up
```

**Issue: API calls failing (CORS, 404, etc.)**
```bash
# Check backend is running
curl http://localhost:8000/health

# Check environment variables
docker-compose exec frontend env | grep VITE_API_URL

# Check browser console for errors
# Open DevTools → Console → Network tab
```

**Issue: Hot reload not working**
```bash
# Check volume mounts are correct in docker-compose.yml
docker-compose exec frontend ls -la /app/src

# Restart frontend
docker-compose restart frontend
```

### Backend Issues

**Issue: Import errors or module not found**
```bash
# Rebuild backend container
make rebuild-backend

# Check Python dependencies are installed
docker-compose exec backend pip list

# View backend logs
make logs-backend
```

**Issue: Database connection failing**
```bash
# Check MONGODB_URL environment variable
docker-compose exec backend env | grep MONGODB

# Test MongoDB connection from backend
make shell-backend
python -c "from pymongo import MongoClient; client = MongoClient('mongodb://mongodb:27017'); print(client.server_info())"
```

### OpenAI API Key Issues

```bash
# Check .env file exists and has key
cat .env | grep OPENAI_API_KEY

# Verify environment variable in backend
docker-compose exec backend env | grep OPENAI_API_KEY

# Restart backend after adding key
docker-compose restart backend

# Test API key (if transcription fails)
# Check logs for authentication errors
make logs-backend
```

### Transcription Workflow Issues

**Episodes stuck in "pending" status:**
```bash
# Check if poll Lambda was invoked
make invoke-poll-lambda

# Check LocalStack logs for Lambda errors
make logs-localstack

# Verify episodes exist in MongoDB
make shell-mongo
db.episodes.find({ transcript_status: "pending" }).pretty()

# Check Step Functions state machine exists
docker-compose exec localstack awslocal stepfunctions list-state-machines
```

**Transcription fails:**
```bash
# Check Whisper service is running
curl http://localhost:9000/

# Check OpenAI API key is set
docker-compose exec backend env | grep OPENAI_API_KEY

# View whisper Lambda logs
make logs-localstack | grep whisper

# Check S3 buckets for audio files
make s3-list-audio
```

### Performance Issues

**Slow container startup:**
- Whisper service downloads models on first start (can take 5-10 minutes)
- LocalStack initializes services (takes 30-60 seconds)
- Solution: Wait for health checks to pass before using services

**High CPU/Memory usage:**
- Whisper service uses significant resources for transcription
- LocalStack can use substantial memory
- Recommended: 8GB RAM, 4 CPU cores for Docker

### Clean Slate (Nuclear Option)

If nothing else works, start completely fresh:

```bash
# Stop all services
make down

# Remove all Docker resources (containers, volumes, networks)
docker-compose down -v
docker system prune -a --volumes

# Clean Lambda artifacts
make clean-lambdas

# Start fresh
make setup
# Edit .env and add OPENAI_API_KEY
make build-all-lambdas
make up
make init-db
make deploy-lambdas

# Verify everything is healthy
make health
make list-lambdas
make s3-list
```

### Getting Help

If you're still experiencing issues:

1. **Check logs**: `make logs` shows all service logs
2. **Check health**: `make health` shows service status
3. **View specific service**: `make logs-backend`, `make logs-localstack`, etc.
4. **GitHub Issues**: Report bugs or ask questions in the repository issues
5. **Docker logs**: `docker-compose logs <service-name>` for detailed logs

## 📝 Scripts

- `npm run dev` - Start frontend development server
- `npm run build` - Build frontend for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

## 🌐 Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## 🚀 Future Enhancements

- **Search Functionality**: Search episodes by title or podcast name
- **Audio Playback**: Play episodes directly in the browser
- **Transcript Search**: Search within transcript text
- **Download Transcripts**: Export transcripts as PDF or text files
- **Podcast Categories**: Organize podcasts by categories and tags
- **Import/Export**: OPML file support for bulk operations
- **Dark Mode**: Theme toggle for better viewing in different lighting
- **Offline Support**: Service Workers for offline access to transcripts
- **Bookmarking**: Save favorite episodes and transcript sections
- **Sharing**: Share episodes and transcript highlights

## 📄 License

MIT

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
