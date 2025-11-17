# Podcast Subscription API

FastAPI backend for managing podcast subscriptions and transcripts with MongoDB and AWS S3.

## Features

- Subscribe to podcasts via RSS feeds
- Automatic RSS feed parsing with metadata extraction
- Episode management with transcript status tracking
- S3 integration for transcript storage and retrieval
- MongoDB for data persistence
- CORS support for frontend integration
- Comprehensive error handling and logging

## API Endpoints

### Podcasts

- `POST /api/podcasts/subscribe` - Subscribe to a podcast by RSS feed URL
- `GET /api/podcasts` - Get all subscribed podcasts
- `DELETE /api/podcasts/{podcast_id}` - Unsubscribe from a podcast

### Episodes

- `GET /api/episodes` - Get episodes with filtering and pagination
  - Query params: `status` (all/completed/processing/pending/failed), `page`, `limit`
- `GET /api/episodes/{episode_id}/transcript` - Get episode transcript

### Health

- `GET /health` - Health check endpoint
- `GET /` - API information

## Prerequisites

- Python 3.9+
- MongoDB 4.4+
- AWS account with S3 bucket (for transcript storage)

## Installation

1. Clone the repository and navigate to the server directory:

```bash
cd server
```

2. Create a virtual environment:

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:

```bash
pip install -r requirements.txt
```

4. Configure environment variables:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
# MongoDB Configuration
MONGODB_URL=mongodb://localhost:27017
MONGODB_DB_NAME=podcast_manager

# AWS S3 Configuration
AWS_ACCESS_KEY_ID=your_access_key_id
AWS_SECRET_ACCESS_KEY=your_secret_access_key
AWS_REGION=us-east-1
S3_BUCKET_NAME=podcast-transcripts

# Application Configuration
APP_HOST=0.0.0.0
APP_PORT=8000
LOG_LEVEL=INFO

# CORS Configuration (comma-separated origins)
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
```

## Running the Application

### Development Mode

```bash
python -m app.main
```

Or with uvicorn directly:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Production Mode

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

## API Documentation

Once the server is running, access the interactive API documentation:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Database Schema

### Podcasts Collection

```javascript
{
  podcast_id: "pod_abc123",          // Generated unique ID
  rss_url: "https://example.com/feed.rss",
  title: "Example Podcast",
  description: "Podcast description",
  image_url: "https://example.com/image.jpg",
  author: "John Doe",
  subscribed_at: ISODate("2025-01-15T10:30:00Z"),
  active: true
}
```

### Episodes Collection

```javascript
{
  episode_id: "ep_xyz789",           // Generated unique ID
  podcast_id: "pod_abc123",          // Foreign key to podcasts
  title: "Episode 1: Introduction",
  description: "Episode description",
  audio_url: "https://example.com/episode1.mp3",
  published_date: ISODate("2025-01-10T08:00:00Z"),
  duration_minutes: 45,
  s3_audio_key: "audio/pod_abc123/ep_xyz789.mp3",
  transcript_status: "completed",    // pending/processing/completed/failed
  transcript_s3_key: "transcripts/pod_abc123/ep_xyz789.txt",
  discovered_at: ISODate("2025-01-15T10:30:00Z"),
  processed_at: ISODate("2025-01-15T11:00:00Z")
}
```

## Usage Examples

### Subscribe to a Podcast

```bash
curl -X POST http://localhost:8000/api/podcasts/subscribe \
  -H "Content-Type: application/json" \
  -d '{"rss_url": "https://feeds.example.com/podcast.rss"}'
```

### Get All Podcasts

```bash
curl http://localhost:8000/api/podcasts
```

### Get Episodes with Filtering

```bash
# Get completed episodes, page 1, 20 per page
curl "http://localhost:8000/api/episodes?status=completed&page=1&limit=20"
```

### Get Episode Transcript

```bash
curl http://localhost:8000/api/episodes/ep_xyz789/transcript
```

### Unsubscribe from Podcast

```bash
curl -X DELETE http://localhost:8000/api/podcasts/pod_abc123
```

## Project Structure

```
server/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application
│   ├── config.py            # Configuration settings
│   ├── models/
│   │   ├── __init__.py
│   │   └── schemas.py       # Pydantic models
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── podcasts.py      # Podcast endpoints
│   │   └── episodes.py      # Episode endpoints
│   ├── database/
│   │   ├── __init__.py
│   │   └── mongodb.py       # MongoDB connection
│   └── services/
│       ├── __init__.py
│       ├── rss_parser.py    # RSS feed parser
│       └── s3_service.py    # S3 operations
├── requirements.txt
├── .env.example
└── README.md
```

## Error Handling

The API uses standard HTTP status codes:

- `200 OK` - Successful request
- `201 Created` - Resource created successfully
- `202 Accepted` - Request accepted (e.g., transcript processing)
- `400 Bad Request` - Invalid request data
- `404 Not Found` - Resource not found
- `409 Conflict` - Resource already exists
- `422 Unprocessable Entity` - Validation error
- `500 Internal Server Error` - Server error

Error responses follow this format:

```json
{
  "error": "Error message",
  "detail": "Detailed error information"
}
```

## Logging

The application logs all requests and errors. Configure log level via the `LOG_LEVEL` environment variable:

- `DEBUG` - Detailed debugging information
- `INFO` - General information (default)
- `WARNING` - Warning messages
- `ERROR` - Error messages only

## Development

### Adding New Endpoints

1. Create route function in appropriate router file
2. Add Pydantic models in `app/models/schemas.py`
3. Include router in `app/main.py`

### Database Indexes

Indexes are automatically created on startup:

- Podcasts: `podcast_id`, `rss_url`, `(active, subscribed_at)`
- Episodes: `episode_id`, `podcast_id`, `(podcast_id, published_date)`, `transcript_status`, `published_date`

## License

MIT
