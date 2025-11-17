import json
import os
import boto3
import logging
import time
from openai import OpenAI
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients
s3_client = boto3.client('s3')
openai_client = OpenAI(api_key=os.environ['OPENAI_API_KEY'])

# Constants
MAX_RETRIES = 3
INITIAL_RETRY_DELAY = 1  # seconds


def download_from_s3(bucket, key, local_path):
    """Download a file from S3 to local path."""
    try:
        logger.info(f"Downloading s3://{bucket}/{key} to {local_path}")
        s3_client.download_file(bucket, key, local_path)
        logger.info(f"Successfully downloaded {key}")
        return True
    except ClientError as e:
        logger.error(f"Failed to download from S3: {e}")
        raise


def upload_to_s3(bucket, key, local_path):
    """Upload a file from local path to S3."""
    try:
        logger.info(f"Uploading {local_path} to s3://{bucket}/{key}")
        s3_client.upload_file(local_path, bucket, key)
        logger.info(f"Successfully uploaded to {key}")
        return True
    except ClientError as e:
        logger.error(f"Failed to upload to S3: {e}")
        raise


def transcribe_audio_with_retry(audio_path, max_retries=MAX_RETRIES):
    """
    Transcribe audio using OpenAI Whisper API with exponential backoff retry logic.

    Args:
        audio_path: Path to the audio file
        max_retries: Maximum number of retry attempts

    Returns:
        Transcript object from OpenAI API
    """
    retry_delay = INITIAL_RETRY_DELAY

    for attempt in range(max_retries + 1):
        try:
            logger.info(f"Attempting transcription (attempt {attempt + 1}/{max_retries + 1})")

            with open(audio_path, 'rb') as audio_file:
                transcript = openai_client.audio.transcriptions.create(
                    model="whisper-1",
                    file=audio_file,
                    response_format="verbose_json",
                    timestamp_granularities=["segment"]
                )

            logger.info("Transcription successful")
            return transcript

        except Exception as e:
            error_message = str(e)
            logger.warning(f"Transcription attempt {attempt + 1} failed: {error_message}")

            # Check if it's a rate limit error or retryable error
            if attempt < max_retries:
                if "rate_limit" in error_message.lower() or "429" in error_message:
                    logger.info(f"Rate limit detected, retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2  # Exponential backoff
                elif "timeout" in error_message.lower() or "503" in error_message:
                    logger.info(f"Service timeout, retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    # Non-retryable error
                    logger.error(f"Non-retryable error: {error_message}")
                    raise
            else:
                logger.error(f"Max retries exceeded. Last error: {error_message}")
                raise


def cleanup_temp_files(*file_paths):
    """Clean up temporary files from /tmp directory."""
    for file_path in file_paths:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                logger.info(f"Cleaned up temporary file: {file_path}")
        except Exception as e:
            logger.warning(f"Failed to clean up {file_path}: {e}")


def lambda_handler(event, context):
    """
    AWS Lambda handler function for transcribing audio chunks using OpenAI Whisper.

    Expected input event format:
    {
        "episode_id": "ep123",
        "chunk_index": 0,
        "s3_key": "chunks/ep123/chunk_0.mp3",
        "start_time_seconds": 0,
        "s3_bucket": "podcast-audio-bucket"  # Optional, uses env var if not provided
    }

    Returns:
    {
        "episode_id": "ep123",
        "chunk_index": 0,
        "transcript_s3_key": "transcripts/ep123/chunk_0.json",
        "start_time_seconds": 0,
        "text_preview": "First 100 characters...",
        "status": "success" | "error",
        "error_message": "..." (only if status is error)
    }
    """

    # Extract input parameters
    episode_id = event.get('episode_id')
    chunk_index = event.get('chunk_index')
    s3_key = event.get('s3_key')
    start_time_seconds = event.get('start_time_seconds', 0)
    s3_bucket = event.get('s3_bucket', os.environ.get('S3_BUCKET'))

    # Validate required parameters
    if not all([episode_id, chunk_index is not None, s3_key, s3_bucket]):
        error_msg = "Missing required parameters: episode_id, chunk_index, s3_key, or s3_bucket"
        logger.error(error_msg)
        return {
            "episode_id": episode_id,
            "chunk_index": chunk_index,
            "status": "error",
            "error_message": error_msg
        }

    logger.info(f"Processing chunk {chunk_index} for episode {episode_id}")

    # Define file paths
    audio_file_name = f"chunk_{chunk_index}.mp3"
    local_audio_path = f"/tmp/{audio_file_name}"
    transcript_file_name = f"chunk_{chunk_index}.json"
    local_transcript_path = f"/tmp/transcript_{transcript_file_name}"
    transcript_s3_key = f"transcripts/{episode_id}/{transcript_file_name}"

    try:
        # Step 1: Download audio chunk from S3
        download_from_s3(s3_bucket, s3_key, local_audio_path)

        # Step 2: Transcribe using OpenAI Whisper API
        transcript = transcribe_audio_with_retry(local_audio_path)

        # Step 3: Prepare transcript data
        transcript_data = {
            "episode_id": episode_id,
            "chunk_index": chunk_index,
            "start_time_seconds": start_time_seconds,
            "transcript": transcript.model_dump() if hasattr(transcript, 'model_dump') else dict(transcript),
            "text": transcript.text,
            "segments": [
                {
                    "id": seg.id,
                    "start": seg.start,
                    "end": seg.end,
                    "text": seg.text
                } for seg in (transcript.segments if hasattr(transcript, 'segments') else [])
            ]
        }

        # Save transcript to local file
        with open(local_transcript_path, 'w') as f:
            json.dump(transcript_data, f, indent=2)

        # Step 4: Upload transcript to S3
        upload_to_s3(s3_bucket, transcript_s3_key, local_transcript_path)

        # Step 5: Prepare response
        text_preview = transcript.text[:100] if transcript.text else ""

        response = {
            "episode_id": episode_id,
            "chunk_index": chunk_index,
            "transcript_s3_key": transcript_s3_key,
            "start_time_seconds": start_time_seconds,
            "text_preview": text_preview,
            "status": "success"
        }

        logger.info(f"Successfully processed chunk {chunk_index} for episode {episode_id}")
        return response

    except Exception as e:
        error_message = f"Error processing chunk: {str(e)}"
        logger.error(error_message, exc_info=True)

        return {
            "episode_id": episode_id,
            "chunk_index": chunk_index,
            "transcript_s3_key": None,
            "start_time_seconds": start_time_seconds,
            "status": "error",
            "error_message": error_message
        }

    finally:
        # Clean up temporary files
        cleanup_temp_files(local_audio_path, local_transcript_path)
