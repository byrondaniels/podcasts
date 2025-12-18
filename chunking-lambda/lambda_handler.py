import json
import os
import logging
import traceback
from typing import Dict, List, Any
import boto3
import requests
from pydub import AudioSegment
from pymongo import MongoClient
from botocore.exceptions import ClientError

# Add bin directory to PATH for ffmpeg binaries
os.environ['PATH'] = f"/var/task/opt/bin:{os.environ.get('PATH', '')}"

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Constants
CHUNK_DURATION_MS = 20 * 60 * 1000  # 20 minutes in milliseconds
EXPORT_BITRATE = "64k"
TMP_DIR = "/tmp"


def get_s3_client():
    """Create S3 client with proper configuration for Minio/LocalStack."""
    endpoint_url = os.environ.get('AWS_ENDPOINT_URL')

    client_kwargs = {
        'region_name': os.environ.get('AWS_REGION', 'us-east-1')
    }

    if endpoint_url:
        client_kwargs['endpoint_url'] = endpoint_url
        # For Minio/LocalStack, we need to use path-style addressing
        client_kwargs['config'] = boto3.session.Config(s3={'addressing_style': 'path'})
        logger.info(f"Using S3 endpoint: {endpoint_url}")

    return boto3.client('s3', **client_kwargs)


# Initialize AWS clients
s3_client = get_s3_client()

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


def download_audio(audio_url: str, episode_id: str) -> str:
    """
    Download audio file from URL to /tmp

    Args:
        audio_url: URL of the audio file
        episode_id: Episode identifier

    Returns:
        Path to downloaded file
    """
    logger.info(f"Downloading audio from {audio_url}")

    try:
        # Stream download to handle large files
        response = requests.get(audio_url, stream=True, timeout=300)
        response.raise_for_status()

        # Determine file extension from Content-Type or URL
        content_type = response.headers.get('Content-Type', '')
        if 'mp3' in content_type or audio_url.endswith('.mp3'):
            ext = 'mp3'
        elif 'mp4' in content_type or audio_url.endswith('.mp4'):
            ext = 'mp4'
        elif 'm4a' in content_type or audio_url.endswith('.m4a'):
            ext = 'm4a'
        else:
            ext = 'mp3'  # Default to mp3

        file_path = os.path.join(TMP_DIR, f"{episode_id}_original.{ext}")

        # Download in chunks to handle large files
        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)

        file_size = os.path.getsize(file_path)
        logger.info(f"Downloaded {file_size / (1024*1024):.2f} MB to {file_path}")

        return file_path

    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to download audio: {str(e)}")
        raise Exception(f"Audio download failed: {str(e)}")


def load_audio(file_path: str) -> AudioSegment:
    """
    Load audio file using pydub

    Args:
        file_path: Path to audio file

    Returns:
        AudioSegment object
    """
    logger.info(f"Loading audio file: {file_path}")

    try:
        audio = AudioSegment.from_file(file_path)
        duration_minutes = len(audio) / (1000 * 60)
        logger.info(f"Loaded audio: {duration_minutes:.2f} minutes, "
                   f"{audio.frame_rate}Hz, {audio.channels} channels")
        return audio

    except Exception as e:
        logger.error(f"Failed to load audio: {str(e)}")
        raise Exception(f"Audio loading failed: {str(e)}")


def create_chunks(audio: AudioSegment, episode_id: str, s3_bucket: str) -> List[Dict[str, Any]]:
    """
    Split audio into chunks and upload to S3

    Args:
        audio: AudioSegment object
        episode_id: Episode identifier
        s3_bucket: S3 bucket name

    Returns:
        List of chunk metadata dictionaries
    """
    total_duration_ms = len(audio)
    num_chunks = (total_duration_ms + CHUNK_DURATION_MS - 1) // CHUNK_DURATION_MS  # Ceiling division

    logger.info(f"Splitting {total_duration_ms/1000:.2f}s audio into {num_chunks} chunks")

    chunks_metadata = []

    for i in range(num_chunks):
        start_ms = i * CHUNK_DURATION_MS
        end_ms = min(start_ms + CHUNK_DURATION_MS, total_duration_ms)

        # Extract chunk
        chunk = audio[start_ms:end_ms]

        # Export to file
        chunk_filename = f"chunk_{i}.mp3"
        chunk_path = os.path.join(TMP_DIR, chunk_filename)

        logger.info(f"Exporting chunk {i}: {start_ms/1000:.2f}s - {end_ms/1000:.2f}s")
        chunk.export(
            chunk_path,
            format="mp3",
            bitrate=EXPORT_BITRATE,
            parameters=["-q:a", "2"]  # Quality setting for MP3
        )

        # Upload to S3
        s3_key = f"chunks/{episode_id}/{chunk_filename}"
        try:
            s3_client.upload_file(
                chunk_path,
                s3_bucket,
                s3_key,
                ExtraArgs={'ContentType': 'audio/mpeg'}
            )
            logger.info(f"Uploaded chunk {i} to s3://{s3_bucket}/{s3_key}")

        except ClientError as e:
            logger.error(f"Failed to upload chunk {i} to S3: {str(e)}")
            raise Exception(f"S3 upload failed for chunk {i}: {str(e)}")

        # Clean up chunk file
        os.remove(chunk_path)

        # Add metadata
        chunks_metadata.append({
            "chunk_index": i,
            "s3_key": s3_key,
            "start_time_seconds": start_ms / 1000,
            "end_time_seconds": end_ms / 1000
        })

    return chunks_metadata


def update_mongodb(episode_id: str, s3_audio_key: str):
    """
    Update MongoDB episode document

    Args:
        episode_id: Episode identifier
        s3_audio_key: S3 key for the original audio file
    """
    try:
        db = get_mongo_connection()
        episodes_collection = db.episodes

        result = episodes_collection.update_one(
            {"episode_id": episode_id},
            {
                "$set": {
                    "transcript_status": "processing",
                    "processing_step": "chunking",
                    "s3_audio_key": s3_audio_key
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
        raise Exception(f"MongoDB update failed: {str(e)}")


def cleanup_tmp(episode_id: str):
    """
    Clean up temporary files

    Args:
        episode_id: Episode identifier
    """
    try:
        for filename in os.listdir(TMP_DIR):
            if episode_id in filename:
                file_path = os.path.join(TMP_DIR, filename)
                os.remove(file_path)
                logger.info(f"Cleaned up: {file_path}")
    except Exception as e:
        logger.warning(f"Error during cleanup: {str(e)}")


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for podcast audio chunking

    Args:
        event: Step Functions input containing episode_id, audio_url, s3_bucket
        context: Lambda context object

    Returns:
        Dictionary with episode_id, total_chunks, and chunks metadata
    """
    logger.info(f"Received event: {json.dumps(event)}")

    # Validate input
    required_fields = ['episode_id', 'audio_url', 's3_bucket']
    for field in required_fields:
        if field not in event:
            error_msg = f"Missing required field: {field}"
            logger.error(error_msg)
            raise ValueError(error_msg)

    episode_id = event['episode_id']
    audio_url = event['audio_url']
    s3_bucket = event['s3_bucket']

    downloaded_file = None

    try:
        # Update status to downloading
        db = get_mongo_connection()
        db.episodes.update_one(
            {"episode_id": episode_id},
            {
                "$set": {
                    "transcript_status": "processing",
                    "processing_step": "downloading"
                }
            }
        )

        # Step 1: Download audio
        downloaded_file = download_audio(audio_url, episode_id)

        # Step 2: Load audio with pydub
        audio = load_audio(downloaded_file)

        # Step 3 & 4: Create chunks and upload to S3
        chunks_metadata = create_chunks(audio, episode_id, s3_bucket)

        # Step 5: Update MongoDB
        s3_audio_key = f"audio/{episode_id}.mp3"
        update_mongodb(episode_id, s3_audio_key)

        # Step 6: Prepare response
        response = {
            "episode_id": episode_id,
            "total_chunks": len(chunks_metadata),
            "chunks": chunks_metadata
        }

        logger.info(f"Successfully processed episode {episode_id}: {len(chunks_metadata)} chunks created")

        return response

    except Exception as e:
        logger.error(f"Error processing episode {episode_id}: {str(e)}")
        logger.error(traceback.format_exc())

        # Update MongoDB with error status
        try:
            db = get_mongo_connection()
            db.episodes.update_one(
                {"episode_id": episode_id},
                {
                    "$set": {
                        "transcript_status": "failed",
                        "processing_step": "chunking",
                        "error_message": str(e)
                    }
                }
            )
        except Exception as db_error:
            logger.error(f"Failed to update error status in MongoDB: {str(db_error)}")

        raise

    finally:
        # Clean up temporary files
        cleanup_tmp(episode_id)
