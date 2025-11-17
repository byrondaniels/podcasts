# MongoDB Setup Scripts

This directory contains database setup and management scripts for the podcast application.

## setup_mongodb.py

A comprehensive MongoDB setup script that creates collections with validation rules, indexes, and sample data for testing.

### Features

- **Schema Validation**: Creates JSON schema validators for both `podcasts` and `episodes` collections
- **Indexes**: Creates all required indexes for optimal query performance
- **Sample Data**: Inserts test data for development and testing
- **Error Handling**: Robust error handling and logging
- **Idempotent**: Can be run multiple times safely

### Prerequisites

1. Install required dependencies:
   ```bash
   pip install -r ../requirements.txt
   ```

2. Set up environment variables:
   ```bash
   export MONGODB_URL="mongodb://localhost:27017"
   export MONGODB_DB_NAME="podcast_db"
   ```

   Or create a `.env` file in the server directory:
   ```env
   MONGODB_URL=mongodb://localhost:27017
   MONGODB_DB_NAME=podcast_db
   ```

### Usage

Run the script from the server directory:

```bash
cd server
python scripts/setup_mongodb.py
```

Or make it executable and run directly:

```bash
chmod +x scripts/setup_mongodb.py
./scripts/setup_mongodb.py
```

### What It Does

#### 1. Creates Collections with Validation

**Podcasts Collection:**
- Validates `podcast_id`, `rss_url`, `title`, `subscribed_at`, and `active` are required
- Ensures `rss_url` matches HTTP/HTTPS URL pattern
- Validates `active` is a boolean

**Episodes Collection:**
- Validates `episode_id`, `podcast_id`, `title`, `audio_url`, `published_date`, and `transcript_status` are required
- Ensures `transcript_status` is one of: `pending`, `processing`, `completed`, `failed`
- Validates numeric fields have minimum values of 0

#### 2. Creates Indexes

**Podcasts Indexes:**
- `podcast_id` (unique)
- `rss_url` (unique)
- `active`
- `last_polled_at`

**Episodes Indexes:**
- `episode_id` (unique)
- `podcast_id` + `published_date` (compound, descending)
- `audio_url` (unique)
- `transcript_status` + `discovered_at` (compound, descending)
- `published_date` (descending)

#### 3. Inserts Sample Data

Creates 3 sample podcasts and 5 sample episodes with various states:
- Completed transcriptions
- Processing transcriptions
- Pending transcriptions
- Failed transcriptions

### Output

The script provides detailed logging of:
- Connection status
- Collection creation/updates
- Index creation
- Sample data insertion
- Final database summary

Example output:
```
2024-01-15 10:30:00 - INFO - Connecting to MongoDB at mongodb://localhost:27017
2024-01-15 10:30:00 - INFO - Successfully connected to MongoDB
2024-01-15 10:30:00 - INFO - Creating podcasts collection...
2024-01-15 10:30:00 - INFO - ✓ Podcasts collection created with validation rules
...
======================================================================
DATABASE SETUP SUMMARY
======================================================================
Collections created: 2 (podcasts, episodes)
Podcasts in database: 3
Episodes in database: 5
...
```

### Troubleshooting

**Connection Errors:**
- Verify MongoDB is running: `mongosh` or `mongo`
- Check `MONGODB_URL` environment variable is set correctly
- Ensure firewall allows connection to MongoDB port (default: 27017)

**Validation Errors:**
- The script will update validators if collections already exist
- To start fresh, drop the collections first:
  ```javascript
  use podcast_db
  db.podcasts.drop()
  db.episodes.drop()
  ```

**Import Errors:**
- Ensure all dependencies are installed: `pip install -r requirements.txt`
- Verify Python version is 3.8 or higher: `python --version`

### Schema Details

For detailed schema information, see the main project README or the inline documentation in `setup_mongodb.py`.

### Integration with Application

The application's FastAPI server (`app/database/mongodb.py`) will automatically create basic indexes on startup. However, this setup script provides:

- More comprehensive validation rules
- Additional indexes for better query performance
- Sample data for testing
- Documentation and maintenance capabilities

Run this script during initial deployment or when updating database schema.
