import json
import os
import boto3
import logging
from datetime import datetime
from pymongo import MongoClient
from botocore.exceptions import ClientError
from typing import Dict, List, Any, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients
s3_client = boto3.client('s3')

# MongoDB connection (initialized lazily)
mongo_client = None
db = None


def get_mongo_connection():
    """Initialize MongoDB connection (reused across Lambda invocations)"""
    global mongo_client, db

    if mongo_client is None:
        mongo_uri = os.environ.get('MONGODB_URI')
        if not mongo_uri:
            raise ValueError("MONGODB_URI environment variable not set")

        mongo_client = MongoClient(mongo_uri)
        db_name = os.environ.get('MONGODB_DB_NAME', 'podcast_db')
        db = mongo_client[db_name]
        logger.info(f"Connected to MongoDB database: {db_name}")

    return db


def download_transcript_from_s3(bucket: str, key: str) -> Dict[str, Any]:
    """
    Download a transcript chunk from S3 and parse JSON.

    Args:
        bucket: S3 bucket name
        key: S3 object key

    Returns:
        Parsed JSON transcript data
    """
    try:
        logger.info(f"Downloading s3://{bucket}/{key}")
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        transcript_data = json.loads(content)
        logger.info(f"Successfully downloaded and parsed {key}")
        return transcript_data
    except ClientError as e:
        logger.error(f"Failed to download from S3: {e}")
        raise
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse JSON from {key}: {e}")
        raise


def upload_to_s3(bucket: str, key: str, content: str, content_type: str = 'text/plain'):
    """
    Upload content to S3.

    Args:
        bucket: S3 bucket name
        key: S3 object key
        content: Content to upload
        content_type: Content-Type header
    """
    try:
        logger.info(f"Uploading to s3://{bucket}/{key}")
        s3_client.put_object(
            Bucket=bucket,
            Key=key,
            Body=content.encode('utf-8'),
            ContentType=content_type
        )
        logger.info(f"Successfully uploaded to {key}")
    except ClientError as e:
        logger.error(f"Failed to upload to S3: {e}")
        raise


def format_timestamp(seconds: float) -> str:
    """
    Format seconds into [HH:MM:SS] timestamp.

    Args:
        seconds: Time in seconds

    Returns:
        Formatted timestamp string
    """
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    return f"[{hours:02d}:{minutes:02d}:{secs:02d}]"


def merge_transcripts(transcripts: List[Dict[str, Any]], s3_bucket: str, add_timestamps: bool = True) -> tuple[str, int]:
    """
    Merge transcript chunks into a single formatted transcript.

    Args:
        transcripts: List of transcript metadata (sorted by chunk_index)
        s3_bucket: S3 bucket name
        add_timestamps: Whether to add timestamps every 5 minutes

    Returns:
        Tuple of (merged_text, total_words)
    """
    merged_text_parts = []
    total_words = 0
    last_timestamp_seconds = -300  # Force timestamp at the beginning

    for transcript_meta in transcripts:
        chunk_index = transcript_meta['chunk_index']
        s3_key = transcript_meta['transcript_s3_key']
        start_time_seconds = transcript_meta.get('start_time_seconds', 0)

        logger.info(f"Processing chunk {chunk_index} from {s3_key}")

        # Download and parse transcript chunk
        transcript_data = download_transcript_from_s3(s3_bucket, s3_key)

        # Extract text from the transcript
        text = transcript_data.get('text', '').strip()

        if not text:
            logger.warning(f"Chunk {chunk_index} has no text content")
            continue

        # Add timestamp header if 5 minutes have passed
        if add_timestamps and (start_time_seconds - last_timestamp_seconds) >= 300:
            timestamp_header = f"\n{format_timestamp(start_time_seconds)}\n"
            merged_text_parts.append(timestamp_header)
            last_timestamp_seconds = start_time_seconds

        # Add the chunk text
        merged_text_parts.append(text)

        # Add paragraph break between chunks
        merged_text_parts.append("\n\n")

        # Count words
        total_words += len(text.split())

    # Join all parts
    merged_text = "".join(merged_text_parts).strip()

    logger.info(f"Merged transcript: {len(merged_text)} characters, {total_words} words")

    return merged_text, total_words


def update_episode_in_mongodb(episode_id: str, transcript_s3_key: str):
    """
    Update MongoDB episode document with completion status.

    Args:
        episode_id: Episode identifier
        transcript_s3_key: S3 key for the final transcript
    """
    try:
        db = get_mongo_connection()
        episodes_collection = db.episodes

        result = episodes_collection.update_one(
            {"episode_id": episode_id},
            {
                "$set": {
                    "status": "completed",
                    "transcript_s3_key": transcript_s3_key,
                    "processed_at": datetime.utcnow()
                }
            },
            upsert=False
        )

        if result.matched_count > 0:
            logger.info(f"Updated MongoDB episode {episode_id}: matched={result.matched_count}, "
                       f"modified={result.modified_count}")
        else:
            logger.warning(f"No episode found with episode_id={episode_id}")

    except Exception as e:
        logger.error(f"Failed to update MongoDB: {str(e)}")
        raise


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda handler function for merging transcript chunks.

    Expected input event format:
    {
        "episode_id": "ep123",
        "total_chunks": 12,
        "transcripts": [
            {
                "chunk_index": 0,
                "transcript_s3_key": "transcripts/ep123/chunk_0.json",
                "start_time_seconds": 0
            },
            ...
        ],
        "s3_bucket": "podcast-audio-bucket"  # Optional, uses env var if not provided
    }

    Returns:
    {
        "episode_id": "ep123",
        "transcript_s3_key": "transcripts/ep123/final.txt",
        "total_words": 15000,
        "status": "completed"
    }
    """
    logger.info(f"Received event: {json.dumps(event)}")

    # Extract input parameters
    episode_id = event.get('episode_id')
    total_chunks = event.get('total_chunks')
    transcripts = event.get('transcripts', [])
    s3_bucket = event.get('s3_bucket', os.environ.get('S3_BUCKET'))

    # Validate required parameters
    if not episode_id:
        error_msg = "Missing required parameter: episode_id"
        logger.error(error_msg)
        return {
            "episode_id": episode_id,
            "status": "error",
            "error_message": error_msg
        }

    if not transcripts:
        error_msg = "No transcripts provided"
        logger.error(error_msg)
        return {
            "episode_id": episode_id,
            "status": "error",
            "error_message": error_msg
        }

    if not s3_bucket:
        error_msg = "S3 bucket not specified in event or environment variables"
        logger.error(error_msg)
        return {
            "episode_id": episode_id,
            "status": "error",
            "error_message": error_msg
        }

    try:
        # Step 1: Sort transcripts by chunk_index
        sorted_transcripts = sorted(transcripts, key=lambda x: x['chunk_index'])
        logger.info(f"Processing {len(sorted_transcripts)} transcript chunks")

        # Step 2: Validate we have all chunks
        if total_chunks and len(sorted_transcripts) != total_chunks:
            logger.warning(f"Expected {total_chunks} chunks but received {len(sorted_transcripts)}")

        # Check for missing chunks
        expected_indices = set(range(len(sorted_transcripts)))
        actual_indices = set(t['chunk_index'] for t in sorted_transcripts)
        missing_indices = expected_indices - actual_indices

        if missing_indices:
            error_msg = f"Missing chunks: {sorted(missing_indices)}"
            logger.error(error_msg)
            return {
                "episode_id": episode_id,
                "status": "error",
                "error_message": error_msg
            }

        # Step 3: Merge transcripts
        merged_text, total_words = merge_transcripts(
            sorted_transcripts,
            s3_bucket,
            add_timestamps=True
        )

        # Step 4: Upload final transcript to S3
        final_transcript_key = f"transcripts/{episode_id}/final.txt"
        upload_to_s3(s3_bucket, final_transcript_key, merged_text, 'text/plain')

        # Step 5: Update MongoDB
        update_episode_in_mongodb(episode_id, final_transcript_key)

        # Step 6: Prepare response
        response = {
            "episode_id": episode_id,
            "transcript_s3_key": final_transcript_key,
            "total_words": total_words,
            "status": "completed"
        }

        logger.info(f"Successfully merged transcripts for episode {episode_id}")
        return response

    except Exception as e:
        error_message = f"Error merging transcripts: {str(e)}"
        logger.error(error_message, exc_info=True)

        # Update MongoDB with error status
        try:
            db = get_mongo_connection()
            db.episodes.update_one(
                {"episode_id": episode_id},
                {
                    "$set": {
                        "status": "error",
                        "error_message": error_message,
                        "processed_at": datetime.utcnow()
                    }
                }
            )
        except Exception as db_error:
            logger.error(f"Failed to update error status in MongoDB: {str(db_error)}")

        return {
            "episode_id": episode_id,
            "status": "error",
            "error_message": error_message
        }
