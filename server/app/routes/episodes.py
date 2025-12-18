"""Episode and transcript management endpoints."""
import logging
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Query, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.database import get_database
from app.models import (
    EpisodeResponse,
    EpisodeListResponse,
    TranscriptResponse,
    TranscriptStatus,
)
from app.services import s3_service, step_functions_service

# Constants
DEFAULT_PAGE_LIMIT = 20
MAX_PAGE_LIMIT = 100

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/episodes", tags=["episodes"])


@router.get("", response_model=EpisodeListResponse)
async def get_episodes(
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by transcript status (all/completed/processing/pending/failed)"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(DEFAULT_PAGE_LIMIT, ge=1, le=MAX_PAGE_LIMIT, description="Items per page"),
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """
    Get episodes from subscribed podcasts.

    Args:
        status_filter: Filter by transcript status (all/completed/processing/pending/failed)
        page: Page number (1-indexed)
        limit: Number of items per page (max 100)
        db: Database instance

    Returns:
        Paginated list of episodes with transcript status
    """
    try:
        logger.info(f"Fetching episodes (status={status_filter}, page={page}, limit={limit})")

        # Get active podcast IDs
        active_podcasts = await db.podcasts.find(
            {"active": True},
            {"podcast_id": 1}
        ).to_list(length=None)

        active_podcast_ids = [p["podcast_id"] for p in active_podcasts]

        if not active_podcast_ids:
            logger.info("No active podcasts found")
            return {
                "episodes": [],
                "total": 0,
                "page": page,
                "limit": limit,
                "has_more": False
            }

        # Build query
        query = {"podcast_id": {"$in": active_podcast_ids}}

        # Add status filter if specified
        if status_filter and status_filter != "all":
            # Validate status
            valid_statuses = ["completed", "processing", "pending", "failed"]
            if status_filter not in valid_statuses:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid status filter. Must be one of: all, {', '.join(valid_statuses)}"
                )
            query["transcript_status"] = status_filter

        # Count total matching episodes
        total = await db.episodes.count_documents(query)

        # Calculate pagination
        skip = (page - 1) * limit

        # Fetch episodes with podcast info using aggregation
        pipeline = [
            {"$match": query},
            {"$sort": {"published_date": -1}},
            {"$skip": skip},
            {"$limit": limit},
            {
                "$lookup": {
                    "from": "podcasts",
                    "localField": "podcast_id",
                    "foreignField": "podcast_id",
                    "as": "podcast"
                }
            },
            {"$unwind": {"path": "$podcast", "preserveNullAndEmptyArrays": True}}
        ]

        cursor = db.episodes.aggregate(pipeline)
        episodes = await cursor.to_list(length=limit)

        # Check if there are more pages
        has_more = (skip + len(episodes)) < total

        logger.info(f"Found {len(episodes)} episodes (total: {total})")

        return {
            "episodes": [_format_episode_response(e) for e in episodes],
            "total": total,
            "page": page,
            "limit": limit,
            "has_more": has_more
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching episodes: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch episodes"
        )


@router.get("/{episode_id}/transcript", response_model=TranscriptResponse)
async def get_episode_transcript(
    episode_id: str,
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """
    Get transcript for a specific episode.

    This endpoint fetches the transcript from S3 or MongoDB depending on storage.

    Args:
        episode_id: ID of the episode
        db: Database instance

    Returns:
        Transcript text and metadata

    Raises:
        HTTPException: If episode not found or transcript not available
    """
    try:
        logger.info(f"Fetching transcript for episode: {episode_id}")

        # Find episode
        episode = await db.episodes.find_one({"episode_id": episode_id})
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode with ID '{episode_id}' not found"
            )

        # Check transcript status
        transcript_status = episode.get("transcript_status", "pending")

        if transcript_status == "pending":
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transcript not yet available (status: pending)"
            )
        elif transcript_status == "processing":
            raise HTTPException(
                status_code=status.HTTP_202_ACCEPTED,
                detail="Transcript is being processed"
            )
        elif transcript_status == "failed":
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Transcript generation failed"
            )

        # Try to get transcript from S3
        transcript_text = None
        transcript_s3_key = episode.get("transcript_s3_key")

        if transcript_s3_key:
            try:
                logger.info(f"Fetching transcript from S3: {transcript_s3_key}")
                transcript_text = await s3_service.get_transcript(transcript_s3_key)
            except Exception as e:
                logger.error(f"Failed to fetch transcript from S3: {e}")
                # Fall back to MongoDB if S3 fails
                transcript_text = None

        # Fallback: Check MongoDB for transcript
        if not transcript_text and "transcript_text" in episode:
            logger.info("Using transcript from MongoDB")
            transcript_text = episode["transcript_text"]

        if not transcript_text:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transcript not found in storage"
            )

        logger.info(f"Successfully retrieved transcript for episode: {episode_id}")

        return {
            "episode_id": episode_id,
            "transcript": transcript_text,
            "status": transcript_status,
            "generated_at": episode.get("processed_at")
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching transcript: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch transcript"
        )


@router.post("/{episode_id}/transcribe")
async def trigger_episode_transcription(
    episode_id: str,
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """
    Trigger transcription for a specific episode.

    This endpoint triggers the Step Functions state machine to process
    the episode audio and generate a transcript.

    Args:
        episode_id: ID of the episode to transcribe
        db: Database instance

    Returns:
        Success message with execution details

    Raises:
        HTTPException: If episode not found or transcription cannot be triggered
    """
    try:
        logger.info(f"Triggering transcription for episode: {episode_id}")

        # Find episode
        episode = await db.episodes.find_one({"episode_id": episode_id})
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode with ID '{episode_id}' not found"
            )

        # Check if episode has audio URL
        audio_url = episode.get("audio_url")
        if not audio_url:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Episode does not have an audio URL"
            )

        # Check current transcript status
        current_status = episode.get("transcript_status", "pending")
        if current_status == "processing":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Episode is already being transcribed"
            )

        # Update episode status to processing
        await db.episodes.update_one(
            {"episode_id": episode_id},
            {"$set": {"transcript_status": "processing"}}
        )

        # Trigger Step Functions execution
        try:
            execution_result = await step_functions_service.trigger_transcription(
                episode_id=episode_id,
                audio_url=audio_url
            )

            logger.info(
                f"Successfully triggered transcription for episode {episode_id}. "
                f"Execution ARN: {execution_result['execution_arn']}"
            )

            return {
                "message": "Transcription started successfully",
                "episode_id": episode_id,
                "execution_arn": execution_result["execution_arn"],
                "status": "processing"
            }

        except ValueError as e:
            # Revert status if Step Functions is not configured
            await db.episodes.update_one(
                {"episode_id": episode_id},
                {"$set": {"transcript_status": current_status}}
            )
            logger.error(f"Step Functions not configured: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=str(e)
            )
        except Exception as e:
            # Revert status on error
            await db.episodes.update_one(
                {"episode_id": episode_id},
                {"$set": {"transcript_status": "failed"}}
            )
            logger.error(f"Failed to trigger Step Functions: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to start transcription: {str(e)}"
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error triggering transcription: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to trigger transcription"
        )


def _format_episode_response(episode_doc: dict) -> EpisodeResponse:
    """Format episode document as response model."""
    # Extract podcast title from joined podcast data
    podcast_title = "Unknown Podcast"
    if "podcast" in episode_doc and episode_doc["podcast"]:
        podcast_title = episode_doc["podcast"].get("title", "Unknown Podcast")

    return EpisodeResponse(
        episode_id=episode_doc["episode_id"],
        podcast_id=episode_doc["podcast_id"],
        podcast_title=podcast_title,
        episode_title=episode_doc["title"],
        title=episode_doc["title"],  # For backwards compatibility
        description=episode_doc.get("description"),
        audio_url=episode_doc.get("audio_url"),
        published_date=episode_doc.get("published_date"),
        duration_minutes=episode_doc.get("duration_minutes"),
        s3_audio_key=episode_doc.get("s3_audio_key"),
        transcript_status=episode_doc.get("transcript_status", "pending"),
        processing_step=episode_doc.get("processing_step"),
        transcript_s3_key=episode_doc.get("transcript_s3_key"),
        discovered_at=episode_doc["discovered_at"],
        processed_at=episode_doc.get("processed_at"),
    )
