import os
import json
import hashlib
import logging
from datetime import datetime
from typing import Dict, List, Optional

import feedparser
import boto3
from pymongo import MongoClient
from pymongo.errors import DuplicateKeyError, PyMongoError
from dateutil import parser as date_parser

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sfn_client = boto3.client('stepfunctions', region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# MongoDB connection (reuse across invocations)
mongo_client = None


def get_mongo_client():
    """Get or create MongoDB client (connection pooling)."""
    global mongo_client
    if mongo_client is None:
        mongodb_uri = os.environ['MONGODB_URI']
        mongo_client = MongoClient(mongodb_uri)
    return mongo_client


def generate_episode_id(audio_url: str) -> str:
    """Generate unique episode ID from audio URL hash."""
    return hashlib.sha256(audio_url.encode('utf-8')).hexdigest()


def parse_episode_date(entry: Dict) -> Optional[datetime]:
    """Parse episode publication date from feed entry."""
    date_fields = ['published', 'pubDate', 'updated']

    for field in date_fields:
        if field in entry:
            try:
                if hasattr(entry, field + '_parsed') and entry[field + '_parsed']:
                    # Use feedparser's parsed time tuple
                    time_struct = getattr(entry, field + '_parsed')
                    return datetime(*time_struct[:6])
                else:
                    # Try to parse the string
                    return date_parser.parse(entry[field])
            except Exception as e:
                logger.warning(f"Failed to parse date from {field}: {e}")
                continue

    return None


def extract_audio_url(entry: Dict) -> Optional[str]:
    """Extract audio URL from feed entry."""
    # Check enclosures first (most common for podcasts)
    if hasattr(entry, 'enclosures') and entry.enclosures:
        for enclosure in entry.enclosures:
            if enclosure.get('type', '').startswith('audio/'):
                return enclosure.get('url')

    # Check links
    if hasattr(entry, 'links'):
        for link in entry.links:
            if link.get('type', '').startswith('audio/'):
                return link.get('href')

    # Fallback to entry link
    if hasattr(entry, 'link'):
        return entry.link

    return None


def parse_rss_feed(feed_url: str) -> Optional[feedparser.FeedParserDict]:
    """Parse RSS feed with error handling."""
    try:
        logger.info(f"Parsing feed: {feed_url}")
        feed = feedparser.parse(feed_url)

        # Check for feed errors
        if feed.bozo:
            logger.warning(f"Feed has issues (bozo): {feed_url}, exception: {feed.get('bozo_exception')}")
            # Continue anyway - many feeds work despite bozo flag

        if not hasattr(feed, 'entries') or len(feed.entries) == 0:
            logger.error(f"No entries found in feed: {feed_url}")
            return None

        return feed

    except Exception as e:
        logger.error(f"Failed to parse feed {feed_url}: {str(e)}", exc_info=True)
        return None


def process_podcast(podcast: Dict, db) -> Dict:
    """
    Process a single podcast: fetch RSS, find new episodes, queue for processing.

    Returns:
        Dict with processing stats (new_episodes, errors)
    """
    podcast_id = str(podcast['_id'])
    feed_url = podcast.get('feed_url') or podcast.get('rss_url')
    podcast_title = podcast.get('title', 'Unknown')

    stats = {
        'podcast_id': podcast_id,
        'podcast_title': podcast_title,
        'new_episodes': 0,
        'errors': []
    }

    logger.info(f"Processing podcast: {podcast_title} ({podcast_id})")

    if not feed_url:
        error = f"No feed URL found for podcast {podcast_id}"
        logger.error(error)
        stats['errors'].append(error)
        return stats

    # Parse RSS feed
    feed = parse_rss_feed(feed_url)
    if not feed:
        error = f"Failed to parse feed for podcast {podcast_id}"
        stats['errors'].append(error)
        return stats

    # Process each episode in the feed
    episodes_collection = db.episodes

    for entry in feed.entries:
        try:
            # Extract audio URL
            audio_url = extract_audio_url(entry)
            if not audio_url:
                logger.warning(f"No audio URL found for entry: {entry.get('title', 'Unknown')}")
                continue

            # Check if episode already exists
            existing = episodes_collection.find_one({'audio_url': audio_url})
            if existing:
                logger.debug(f"Episode already exists: {audio_url}")
                continue

            # Generate episode ID
            episode_id = generate_episode_id(audio_url)

            # Parse episode metadata
            title = entry.get('title', 'Untitled Episode')
            description = entry.get('description') or entry.get('summary', '')
            published_date = parse_episode_date(entry)

            # Create episode document
            episode_doc = {
                '_id': episode_id,
                'episode_id': episode_id,
                'podcast_id': podcast_id,
                'title': title,
                'description': description,
                'audio_url': audio_url,
                'published_date': published_date,
                'status': 'pending',
                'created_at': datetime.utcnow(),
                'updated_at': datetime.utcnow()
            }

            # Insert episode into MongoDB
            try:
                episodes_collection.insert_one(episode_doc)
                logger.info(f"Inserted new episode: {title} ({episode_id})")
                stats['new_episodes'] += 1

                # Trigger Step Functions workflow
                try:
                    trigger_step_function(episode_id, audio_url)
                    logger.info(f"Triggered Step Function for episode {episode_id}")

                except Exception as sf_error:
                    error = f"Failed to trigger Step Function for {episode_id}: {str(sf_error)}"
                    logger.error(error, exc_info=True)
                    stats['errors'].append(error)

                    # Update episode status to failed
                    episodes_collection.update_one(
                        {'_id': episode_id},
                        {'$set': {'status': 'failed', 'error': str(sf_error)}}
                    )

            except DuplicateKeyError:
                logger.warning(f"Duplicate episode detected (race condition): {episode_id}")
                continue

            except Exception as db_error:
                error = f"Failed to insert episode {episode_id}: {str(db_error)}"
                logger.error(error, exc_info=True)
                stats['errors'].append(error)

        except Exception as entry_error:
            error = f"Error processing entry in {podcast_title}: {str(entry_error)}"
            logger.error(error, exc_info=True)
            stats['errors'].append(error)
            continue

    return stats


def trigger_step_function(episode_id: str, audio_url: str) -> None:
    """Trigger Step Functions workflow for episode processing."""
    step_function_arn = os.environ['STEP_FUNCTION_ARN']

    input_data = {
        'episode_id': episode_id,
        'audio_url': audio_url,
        's3_bucket': 'podcast-audio-bucket'
    }

    response = sfn_client.start_execution(
        stateMachineArn=step_function_arn,
        name=f"episode-{episode_id}-{int(datetime.utcnow().timestamp())}",
        input=json.dumps(input_data)
    )

    logger.info(f"Step Function execution started: {response['executionArn']}")


def lambda_handler(event, context):
    """
    Lambda handler for RSS feed polling.

    Queries MongoDB for active podcasts, parses their RSS feeds,
    and queues new episodes for processing.
    """
    logger.info("Starting RSS feed polling")
    logger.info(f"Event: {json.dumps(event)}")

    overall_stats = {
        'total_podcasts': 0,
        'processed_podcasts': 0,
        'total_new_episodes': 0,
        'errors': []
    }

    try:
        # Connect to MongoDB
        client = get_mongo_client()
        db = client.get_database()  # Uses default database from connection string
        podcasts_collection = db.podcasts

        # Query for active podcasts
        active_podcasts = list(podcasts_collection.find({'active': True}))
        overall_stats['total_podcasts'] = len(active_podcasts)

        logger.info(f"Found {len(active_podcasts)} active podcasts")

        if len(active_podcasts) == 0:
            logger.warning("No active podcasts found")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No active podcasts to process',
                    'stats': overall_stats
                })
            }

        # Process each podcast
        podcast_results = []
        for podcast in active_podcasts:
            try:
                stats = process_podcast(podcast, db)
                podcast_results.append(stats)
                overall_stats['processed_podcasts'] += 1
                overall_stats['total_new_episodes'] += stats['new_episodes']

                if stats['errors']:
                    overall_stats['errors'].extend(stats['errors'])

            except Exception as podcast_error:
                error = f"Failed to process podcast {podcast.get('_id')}: {str(podcast_error)}"
                logger.error(error, exc_info=True)
                overall_stats['errors'].append(error)
                continue

        # Log summary
        logger.info(f"RSS polling complete. Processed {overall_stats['processed_podcasts']} podcasts, "
                   f"found {overall_stats['total_new_episodes']} new episodes")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'RSS polling completed',
                'stats': overall_stats,
                'podcast_results': podcast_results
            }, default=str)
        }

    except PyMongoError as db_error:
        error = f"MongoDB error: {str(db_error)}"
        logger.error(error, exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error,
                'stats': overall_stats
            })
        }

    except Exception as e:
        error = f"Unexpected error: {str(e)}"
        logger.error(error, exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error,
                'stats': overall_stats
            })
        }
