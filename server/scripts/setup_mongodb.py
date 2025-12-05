#!/usr/bin/env python3
"""
MongoDB Setup Script for Podcast Application

This script creates collections with validation rules, indexes, and sample data
for the podcast application.

Usage:
    export MONGODB_URL="mongodb://localhost:27017"
    export MONGODB_DB_NAME="podcast_db"
    python setup_mongodb.py
"""

import os
import sys
import logging
from datetime import datetime, timedelta
from pymongo import MongoClient, ASCENDING, DESCENDING
from pymongo.errors import CollectionInvalid, OperationFailure

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def get_mongodb_connection():
    """Get MongoDB connection from environment variables."""
    mongodb_url = os.getenv('MONGODB_URL')
    mongodb_db_name = os.getenv('MONGODB_DB_NAME', 'podcast_db')

    if not mongodb_url:
        logger.error("MONGODB_URL environment variable not set")
        sys.exit(1)

    try:
        logger.info(f"Connecting to MongoDB at {mongodb_url}")
        client = MongoClient(mongodb_url, serverSelectionTimeoutMS=5000)
        # Test connection
        client.admin.command('ping')
        logger.info("Successfully connected to MongoDB")

        db = client[mongodb_db_name]
        return client, db
    except Exception as e:
        logger.error(f"Failed to connect to MongoDB: {e}")
        sys.exit(1)


def create_podcasts_collection(db):
    """Create podcasts collection with validation rules."""
    logger.info("Creating podcasts collection...")

    # Define JSON schema validation
    podcasts_validator = {
        '$jsonSchema': {
            'bsonType': 'object',
            'required': ['podcast_id', 'rss_url', 'title', 'subscribed_at', 'active'],
            'properties': {
                'podcast_id': {
                    'bsonType': 'string',
                    'description': 'Unique podcast identifier - required'
                },
                'rss_url': {
                    'bsonType': 'string',
                    'pattern': '^https?://.+',
                    'description': 'RSS feed URL - must be valid HTTP(S) URL - required'
                },
                'title': {
                    'bsonType': 'string',
                    'description': 'Podcast title - required'
                },
                'description': {
                    'bsonType': 'string',
                    'description': 'Podcast description'
                },
                'image_url': {
                    'bsonType': 'string',
                    'description': 'URL to podcast cover image'
                },
                'author': {
                    'bsonType': 'string',
                    'description': 'Podcast author/creator'
                },
                'website_url': {
                    'bsonType': 'string',
                    'description': 'Podcast website URL'
                },
                'language': {
                    'bsonType': 'string',
                    'description': 'Podcast language code'
                },
                'subscribed_at': {
                    'bsonType': 'date',
                    'description': 'Date when podcast was subscribed - required'
                },
                'last_polled_at': {
                    'bsonType': 'date',
                    'description': 'Last time RSS feed was polled'
                },
                'active': {
                    'bsonType': 'bool',
                    'description': 'Whether podcast is actively being tracked - required'
                }
            }
        }
    }

    try:
        db.create_collection('podcasts', validator=podcasts_validator)
        logger.info("✓ Podcasts collection created with validation rules")
    except CollectionInvalid:
        logger.warning("Podcasts collection already exists, updating validator...")
        db.command('collMod', 'podcasts', validator=podcasts_validator)
        logger.info("✓ Podcasts collection validator updated")
    except Exception as e:
        logger.error(f"Error creating podcasts collection: {e}")
        raise


def create_episodes_collection(db):
    """Create episodes collection with validation rules."""
    logger.info("Creating episodes collection...")

    # Define JSON schema validation
    episodes_validator = {
        '$jsonSchema': {
            'bsonType': 'object',
            'required': ['episode_id', 'podcast_id', 'title', 'audio_url', 'published_date', 'transcript_status'],
            'properties': {
                'episode_id': {
                    'bsonType': 'string',
                    'description': 'Unique episode identifier - required'
                },
                'podcast_id': {
                    'bsonType': 'string',
                    'description': 'Reference to parent podcast - required'
                },
                'title': {
                    'bsonType': 'string',
                    'description': 'Episode title - required'
                },
                'description': {
                    'bsonType': 'string',
                    'description': 'Episode description'
                },
                'audio_url': {
                    'bsonType': 'string',
                    'description': 'URL to audio file - required'
                },
                'published_date': {
                    'bsonType': 'date',
                    'description': 'Episode publication date - required'
                },
                'duration_minutes': {
                    'bsonType': ['number', 'null'],
                    'minimum': 0,
                    'description': 'Episode duration in minutes'
                },
                'file_size_mb': {
                    'bsonType': ['number', 'null'],
                    'minimum': 0,
                    'description': 'Audio file size in megabytes'
                },
                's3_audio_key': {
                    'bsonType': 'string',
                    'description': 'S3 key for stored audio file'
                },
                'transcript_status': {
                    'enum': ['pending', 'processing', 'completed', 'failed'],
                    'description': 'Transcription status - required, must be one of: pending, processing, completed, failed'
                },
                'transcript_s3_key': {
                    'bsonType': 'string',
                    'description': 'S3 key for transcript file'
                },
                'transcript_word_count': {
                    'bsonType': ['int', 'null'],
                    'minimum': 0,
                    'description': 'Word count of transcript'
                },
                'discovered_at': {
                    'bsonType': 'date',
                    'description': 'When episode was first discovered'
                },
                'processed_at': {
                    'bsonType': 'date',
                    'description': 'When episode processing completed'
                },
                'error_message': {
                    'bsonType': 'string',
                    'description': 'Error message if processing failed'
                }
            }
        }
    }

    try:
        db.create_collection('episodes', validator=episodes_validator)
        logger.info("✓ Episodes collection created with validation rules")
    except CollectionInvalid:
        logger.warning("Episodes collection already exists, updating validator...")
        db.command('collMod', 'episodes', validator=episodes_validator)
        logger.info("✓ Episodes collection validator updated")
    except Exception as e:
        logger.error(f"Error creating episodes collection: {e}")
        raise


def create_podcasts_indexes(db):
    """Create indexes for podcasts collection."""
    logger.info("Creating indexes for podcasts collection...")

    podcasts = db.podcasts

    try:
        # Drop existing indexes except _id
        podcasts.drop_indexes()

        # Create indexes
        podcasts.create_index([('podcast_id', ASCENDING)], unique=True, name='podcast_id_unique')
        logger.info("  ✓ Created unique index on podcast_id")

        podcasts.create_index([('rss_url', ASCENDING)], unique=True, name='rss_url_unique')
        logger.info("  ✓ Created unique index on rss_url")

        podcasts.create_index([('active', ASCENDING)], name='active_idx')
        logger.info("  ✓ Created index on active")

        podcasts.create_index([('last_polled_at', ASCENDING)], name='last_polled_at_idx')
        logger.info("  ✓ Created index on last_polled_at")

        logger.info("✓ All podcasts indexes created successfully")
    except Exception as e:
        logger.error(f"Error creating podcasts indexes: {e}")
        raise


def create_episodes_indexes(db):
    """Create indexes for episodes collection."""
    logger.info("Creating indexes for episodes collection...")

    episodes = db.episodes

    try:
        # Drop existing indexes except _id
        episodes.drop_indexes()

        # Create indexes
        episodes.create_index([('episode_id', ASCENDING)], unique=True, name='episode_id_unique')
        logger.info("  ✓ Created unique index on episode_id")

        episodes.create_index(
            [('podcast_id', ASCENDING), ('published_date', DESCENDING)],
            name='podcast_published_compound'
        )
        logger.info("  ✓ Created compound index on podcast_id + published_date")

        episodes.create_index([('audio_url', ASCENDING)], unique=True, name='audio_url_unique')
        logger.info("  ✓ Created unique index on audio_url")

        episodes.create_index(
            [('transcript_status', ASCENDING), ('discovered_at', DESCENDING)],
            name='transcript_status_discovered_compound'
        )
        logger.info("  ✓ Created compound index on transcript_status + discovered_at")

        episodes.create_index([('published_date', DESCENDING)], name='published_date_idx')
        logger.info("  ✓ Created index on published_date")

        logger.info("✓ All episodes indexes created successfully")
    except Exception as e:
        logger.error(f"Error creating episodes indexes: {e}")
        raise


def create_bulk_transcribe_jobs_collection(db):
    """Create bulk transcribe jobs collection."""
    logger.info("Creating bulk_transcribe_jobs collection...")

    jobs_validator = {
        '$jsonSchema': {
            'bsonType': 'object',
            'required': ['job_id', 'rss_url', 'status', 'total_episodes', 'created_at'],
            'properties': {
                'job_id': {
                    'bsonType': 'string',
                    'description': 'Unique job identifier - required'
                },
                'rss_url': {
                    'bsonType': 'string',
                    'description': 'RSS feed URL being processed - required'
                },
                'podcast_title': {
                    'bsonType': 'string',
                    'description': 'Podcast title'
                },
                'status': {
                    'enum': ['pending', 'running', 'paused', 'completed', 'failed', 'cancelled'],
                    'description': 'Job status - required'
                },
                'total_episodes': {
                    'bsonType': 'int',
                    'minimum': 0,
                    'description': 'Total episodes to process - required'
                },
                'processed_episodes': {
                    'bsonType': 'int',
                    'minimum': 0,
                    'description': 'Number of episodes processed'
                },
                'successful_episodes': {
                    'bsonType': 'int',
                    'minimum': 0,
                    'description': 'Number of successfully transcribed episodes'
                },
                'failed_episodes': {
                    'bsonType': 'int',
                    'minimum': 0,
                    'description': 'Number of failed episodes'
                },
                'created_at': {
                    'bsonType': 'date',
                    'description': 'Job creation timestamp - required'
                },
                'updated_at': {
                    'bsonType': 'date',
                    'description': 'Last update timestamp'
                },
                'completed_at': {
                    'bsonType': ['date', 'null'],
                    'description': 'Job completion timestamp'
                },
                'current_episode': {
                    'bsonType': ['string', 'null'],
                    'description': 'Currently processing episode title'
                },
                'episodes': {
                    'bsonType': 'array',
                    'description': 'Array of episode progress objects'
                }
            }
        }
    }

    try:
        db.create_collection('bulk_transcribe_jobs', validator=jobs_validator)
        logger.info("✓ Bulk transcribe jobs collection created with validation rules")
    except CollectionInvalid:
        logger.warning("Bulk transcribe jobs collection already exists, updating validator...")
        db.command('collMod', 'bulk_transcribe_jobs', validator=jobs_validator)
        logger.info("✓ Bulk transcribe jobs collection validator updated")
    except Exception as e:
        logger.error(f"Error creating bulk transcribe jobs collection: {e}")
        raise


def create_bulk_transcribe_jobs_indexes(db):
    """Create indexes for bulk transcribe jobs collection."""
    logger.info("Creating indexes for bulk_transcribe_jobs collection...")

    jobs = db.bulk_transcribe_jobs

    try:
        # Drop existing indexes except _id
        jobs.drop_indexes()

        # Create indexes
        jobs.create_index([('job_id', ASCENDING)], unique=True, name='job_id_unique')
        logger.info("  ✓ Created unique index on job_id")

        jobs.create_index([('created_at', DESCENDING)], name='created_at_idx')
        logger.info("  ✓ Created index on created_at")

        jobs.create_index([('status', ASCENDING)], name='status_idx')
        logger.info("  ✓ Created index on status")

        logger.info("✓ All bulk transcribe jobs indexes created successfully")
    except Exception as e:
        logger.error(f"Error creating bulk transcribe jobs indexes: {e}")
        raise


def insert_sample_data(db):
    """Insert sample data for testing."""
    logger.info("Inserting sample data...")

    podcasts = db.podcasts
    episodes = db.episodes

    try:
        # Sample podcasts
        sample_podcasts = [
            {
                'podcast_id': 'pod_test_001',
                'rss_url': 'https://feeds.example.com/tech-podcast',
                'title': 'Tech Talk Daily',
                'description': 'Daily discussions about technology trends and innovations',
                'image_url': 'https://example.com/images/tech-talk.jpg',
                'author': 'Jane Smith',
                'website_url': 'https://techtalkdaily.example.com',
                'language': 'en',
                'subscribed_at': datetime.utcnow() - timedelta(days=30),
                'last_polled_at': datetime.utcnow() - timedelta(hours=2),
                'active': True
            },
            {
                'podcast_id': 'pod_test_002',
                'rss_url': 'https://feeds.example.com/science-weekly',
                'title': 'Science Weekly',
                'description': 'Weekly podcast exploring the latest in science and research',
                'image_url': 'https://example.com/images/science-weekly.jpg',
                'author': 'Dr. John Doe',
                'website_url': 'https://scienceweekly.example.com',
                'language': 'en',
                'subscribed_at': datetime.utcnow() - timedelta(days=60),
                'last_polled_at': datetime.utcnow() - timedelta(days=1),
                'active': True
            },
            {
                'podcast_id': 'pod_test_003',
                'rss_url': 'https://feeds.example.com/history-stories',
                'title': 'History Stories',
                'description': 'Fascinating stories from history',
                'image_url': 'https://example.com/images/history-stories.jpg',
                'author': 'Sarah Johnson',
                'website_url': 'https://historystories.example.com',
                'language': 'en',
                'subscribed_at': datetime.utcnow() - timedelta(days=90),
                'last_polled_at': datetime.utcnow() - timedelta(days=7),
                'active': False
            }
        ]

        # Insert podcasts (skip if already exist)
        for podcast in sample_podcasts:
            try:
                podcasts.insert_one(podcast)
                logger.info(f"  ✓ Inserted podcast: {podcast['title']}")
            except Exception:
                logger.info(f"  - Podcast already exists: {podcast['title']}")

        # Sample episodes
        sample_episodes = [
            {
                'episode_id': 'ep_test_001',
                'podcast_id': 'pod_test_001',
                'title': 'AI Revolution: What\'s Next?',
                'description': 'Exploring the future of artificial intelligence',
                'audio_url': 'https://cdn.example.com/audio/tech-001.mp3',
                'published_date': datetime.utcnow() - timedelta(days=1),
                'duration_minutes': 45,
                'file_size_mb': 42.5,
                's3_audio_key': 'podcasts/tech-talk/2024/episode-001.mp3',
                'transcript_status': 'completed',
                'transcript_s3_key': 'transcripts/tech-talk/2024/episode-001.json',
                'transcript_word_count': 8500,
                'discovered_at': datetime.utcnow() - timedelta(days=1, hours=2),
                'processed_at': datetime.utcnow() - timedelta(days=1, hours=1)
            },
            {
                'episode_id': 'ep_test_002',
                'podcast_id': 'pod_test_001',
                'title': 'Cloud Computing Trends',
                'description': 'Latest trends in cloud infrastructure',
                'audio_url': 'https://cdn.example.com/audio/tech-002.mp3',
                'published_date': datetime.utcnow() - timedelta(days=2),
                'duration_minutes': 38,
                'file_size_mb': 36.2,
                's3_audio_key': 'podcasts/tech-talk/2024/episode-002.mp3',
                'transcript_status': 'processing',
                'discovered_at': datetime.utcnow() - timedelta(days=2, hours=3)
            },
            {
                'episode_id': 'ep_test_003',
                'podcast_id': 'pod_test_001',
                'title': 'Cybersecurity Best Practices',
                'description': 'How to keep your data safe',
                'audio_url': 'https://cdn.example.com/audio/tech-003.mp3',
                'published_date': datetime.utcnow() - timedelta(days=3),
                'duration_minutes': 52,
                'file_size_mb': 49.8,
                'transcript_status': 'pending',
                'discovered_at': datetime.utcnow() - timedelta(hours=5)
            },
            {
                'episode_id': 'ep_test_004',
                'podcast_id': 'pod_test_002',
                'title': 'Climate Change Research Update',
                'description': 'New findings on global climate patterns',
                'audio_url': 'https://cdn.example.com/audio/science-001.mp3',
                'published_date': datetime.utcnow() - timedelta(days=7),
                'duration_minutes': 60,
                'file_size_mb': 57.3,
                's3_audio_key': 'podcasts/science-weekly/2024/episode-001.mp3',
                'transcript_status': 'completed',
                'transcript_s3_key': 'transcripts/science-weekly/2024/episode-001.json',
                'transcript_word_count': 11200,
                'discovered_at': datetime.utcnow() - timedelta(days=7, hours=4),
                'processed_at': datetime.utcnow() - timedelta(days=7, hours=2)
            },
            {
                'episode_id': 'ep_test_005',
                'podcast_id': 'pod_test_002',
                'title': 'Quantum Computing Breakthrough',
                'description': 'Scientists achieve new quantum milestone',
                'audio_url': 'https://cdn.example.com/audio/science-002.mp3',
                'published_date': datetime.utcnow() - timedelta(days=14),
                'duration_minutes': 55,
                'file_size_mb': 52.1,
                's3_audio_key': 'podcasts/science-weekly/2024/episode-002.mp3',
                'transcript_status': 'failed',
                'error_message': 'Audio quality too low for transcription',
                'discovered_at': datetime.utcnow() - timedelta(days=14, hours=6)
            }
        ]

        # Insert episodes (skip if already exist)
        for episode in sample_episodes:
            try:
                episodes.insert_one(episode)
                logger.info(f"  ✓ Inserted episode: {episode['title']}")
            except Exception:
                logger.info(f"  - Episode already exists: {episode['title']}")

        logger.info("✓ Sample data insertion completed")
    except Exception as e:
        logger.error(f"Error inserting sample data: {e}")
        raise


def display_summary(db):
    """Display summary of database setup."""
    logger.info("\n" + "="*70)
    logger.info("DATABASE SETUP SUMMARY")
    logger.info("="*70)

    # Count documents
    podcasts_count = db.podcasts.count_documents({})
    episodes_count = db.episodes.count_documents({})
    jobs_count = db.bulk_transcribe_jobs.count_documents({})

    logger.info(f"Collections created: 3 (podcasts, episodes, bulk_transcribe_jobs)")
    logger.info(f"Podcasts in database: {podcasts_count}")
    logger.info(f"Episodes in database: {episodes_count}")
    logger.info(f"Bulk transcribe jobs in database: {jobs_count}")

    # Display indexes
    logger.info("\nPodcasts Indexes:")
    for index in db.podcasts.list_indexes():
        logger.info(f"  - {index['name']}: {index.get('key', {})}")

    logger.info("\nEpisodes Indexes:")
    for index in db.episodes.list_indexes():
        logger.info(f"  - {index['name']}: {index.get('key', {})}")

    logger.info("\nBulk Transcribe Jobs Indexes:")
    for index in db.bulk_transcribe_jobs.list_indexes():
        logger.info(f"  - {index['name']}: {index.get('key', {})}")

    logger.info("\n" + "="*70)
    logger.info("Setup completed successfully!")
    logger.info("="*70 + "\n")


def main():
    """Main setup function."""
    logger.info("Starting MongoDB setup for Podcast Application\n")

    # Get database connection
    client, db = get_mongodb_connection()

    try:
        # Create collections with validation
        create_podcasts_collection(db)
        create_episodes_collection(db)
        create_bulk_transcribe_jobs_collection(db)

        # Create indexes
        create_podcasts_indexes(db)
        create_episodes_indexes(db)
        create_bulk_transcribe_jobs_indexes(db)

        # Insert sample data
        insert_sample_data(db)

        # Display summary
        display_summary(db)

    except Exception as e:
        logger.error(f"Setup failed: {e}")
        sys.exit(1)
    finally:
        client.close()
        logger.info("Database connection closed")


if __name__ == '__main__':
    main()
