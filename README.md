# Podcast Manager

A modern React application for managing podcast subscriptions and viewing episode transcripts. Built with TypeScript, React hooks, and a clean, responsive UI.

## Features

### Podcast Subscriptions
- **Subscribe to Podcasts**: Add podcasts using their RSS feed URLs
- **View Subscriptions**: Display all subscribed podcasts with title, description, and thumbnail
- **Unsubscribe**: Remove podcasts from your subscription list
- **Form Validation**: Real-time validation for RSS feed URLs

### Episode Transcripts
- **Browse Episodes**: View episodes from all subscribed podcasts in reverse chronological order
- **Filter Episodes**: Filter by status (All, Completed, Processing)
- **Pagination**: Navigate through episodes with 20 per page
- **View Transcripts**: Read full episode transcripts in a modal viewer
- **Copy to Clipboard**: Easily copy transcript text for external use
- **Status Indicators**: Visual badges showing transcript processing status

### Common Features
- **Loading States**: Skeleton loaders and spinners during API calls
- **Error Handling**: User-friendly error messages with retry options
- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices
- **Tab Navigation**: Easy switching between Subscriptions and Transcripts views

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

## 🚀 Quick Start with Docker

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (version 20.10 or higher)
- [Docker Compose](https://docs.docker.com/compose/install/) (version 2.0 or higher)
- Make (optional, but recommended)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd podcasts
   ```

2. **Set up environment variables**:
   ```bash
   make setup
   # or manually:
   cp .env.example .env
   ```

3. **Edit `.env` and add your OpenAI API key**:
   ```bash
   # Edit the OPENAI_API_KEY in .env
   OPENAI_API_KEY=your-actual-api-key-here
   ```

4. **Start all services**:
   ```bash
   make up
   # or manually:
   docker-compose up -d
   ```

5. **Initialize the database** (first time only):
   ```bash
   make init-db
   # or manually:
   docker-compose exec backend python scripts/setup_mongodb.py
   ```

6. **Access the application**:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000
   - API Documentation: http://localhost:8000/docs
   - MongoDB: mongodb://localhost:27017

### Makefile Commands

The project includes a comprehensive Makefile for easy management:

```bash
make help              # Show all available commands
make setup             # Initial setup - copy .env.example to .env
make up                # Start all services
make down              # Stop all services
make restart           # Restart all services
make logs              # View logs from all services
make logs-backend      # View backend logs only
make logs-frontend     # View frontend logs only
make ps                # Show status of all services
make health            # Check health of all services
make init-db           # Initialize MongoDB with schemas and sample data
make clean             # Stop services and remove volumes (deletes data)
make rebuild           # Rebuild all containers from scratch
make shell-backend     # Open shell in backend container
make shell-frontend    # Open shell in frontend container
make shell-mongo       # Open MongoDB shell
make backup-db         # Backup MongoDB database
make s3-list           # List S3 buckets in LocalStack
make install           # Full installation (setup + up)
make dev               # Start services and follow logs
```

## 🐳 Docker Architecture

### Services

#### 1. MongoDB
- **Image**: mongo:7
- **Port**: 27017
- **Purpose**: Primary database for podcasts and episodes
- **Volume**: `mongodb-data` for persistence
- **Initialization**: Automatic schema and index creation

#### 2. LocalStack
- **Image**: localstack/localstack
- **Port**: 4566
- **Services**: S3, Lambda, Step Functions
- **Purpose**: AWS service emulation for local development
- **Volume**: `localstack-data` for persistence
- **Auto-init**: Creates S3 buckets on startup

#### 3. Backend (FastAPI)
- **Build**: `./server/Dockerfile`
- **Port**: 8000
- **Hot Reload**: Enabled via volume mounts
- **Health Check**: `/health` endpoint
- **Dependencies**: MongoDB, LocalStack

#### 4. Frontend (React + Vite)
- **Build**: `./Dockerfile`
- **Port**: 3000
- **Hot Reload**: Enabled via volume mounts
- **Health Check**: HTTP on port 3000
- **Dependencies**: Backend API

### Networking

All services run on a shared Docker network (`podcast-network`), allowing them to communicate using service names:
- Backend connects to MongoDB at `mongodb://mongodb:27017`
- Backend connects to LocalStack at `http://localstack:4566`
- Frontend connects to Backend at `http://backend:8000`

### Data Persistence

Two named volumes ensure data persists across container restarts:
- `podcast-mongodb-data`: MongoDB database files
- `podcast-localstack-data`: LocalStack state and S3 objects

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
```

### Port Conflicts
If ports 3000, 8000, 27017, or 4566 are already in use:
1. Stop conflicting services
2. Or modify ports in `docker-compose.yml`

### Database Connection Issues
```bash
# Check MongoDB is running
make shell-mongo

# Reinitialize database
make init-db
```

### LocalStack Issues
```bash
# View LocalStack logs
make logs-localstack

# Check LocalStack health
curl http://localhost:4566/_localstack/health
```

### Clean Slate
```bash
# Remove all containers and volumes
make clean

# Rebuild everything
make rebuild

# Start fresh
make up
make init-db
```

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
