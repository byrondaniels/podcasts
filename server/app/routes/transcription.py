"""
Transcription API routes.
Provides endpoints to trigger and monitor transcription workflows.
"""
import logging
from typing import Optional
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel

from app.database.mongodb import get_database
from app.services.orchestration_service import get_orchestration_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/transcription", tags=["transcription"])


class TranscribeRequest(BaseModel):
    """Request to start transcription for an episode."""
    episode_id: str
    audio_url: Optional[str] = None  # Optional - will look up from DB if not provided


class TranscribeResponse(BaseModel):
    """Response from transcription request."""
    status: str
    episode_id: str
    message: str


class TranscriptionStatusResponse(BaseModel):
    """Response with transcription status."""
    episode_id: str
    transcript_status: str
    transcript_s3_key: Optional[str] = None
    error_message: Optional[str] = None


@router.post("/start", response_model=TranscribeResponse)
async def start_transcription(
    request: TranscribeRequest,
    background_tasks: BackgroundTasks
):
    """
    Start transcription workflow for an episode.

    This endpoint triggers the transcription workflow in the background
    and returns immediately. Use the status endpoint to check progress.
    """
    db = get_database()
    episodes_collection = db.episodes

    # Look up the episode
    episode = episodes_collection.find_one({"episode_id": request.episode_id})
    if not episode:
        raise HTTPException(status_code=404, detail=f"Episode {request.episode_id} not found")

    # Get audio URL from request or episode
    audio_url = request.audio_url or episode.get("audio_url")
    if not audio_url:
        raise HTTPException(status_code=400, detail="No audio URL provided or found for episode")

    # Check if already processing or completed
    current_status = episode.get("transcript_status", "pending")
    if current_status == "processing":
        return TranscribeResponse(
            status="already_processing",
            episode_id=request.episode_id,
            message="Transcription is already in progress"
        )
    if current_status == "completed":
        return TranscribeResponse(
            status="already_completed",
            episode_id=request.episode_id,
            message="Transcription is already completed"
        )

    # Start transcription in background
    orchestration_service = get_orchestration_service()

    async def run_transcription():
        try:
            await orchestration_service.transcribe_episode(
                episode_id=request.episode_id,
                audio_url=audio_url
            )
        except Exception as e:
            logger.error(f"Background transcription failed for {request.episode_id}: {e}")

    background_tasks.add_task(run_transcription)

    logger.info(f"Started transcription workflow for episode {request.episode_id}")

    return TranscribeResponse(
        status="started",
        episode_id=request.episode_id,
        message="Transcription workflow started"
    )


@router.get("/status/{episode_id}", response_model=TranscriptionStatusResponse)
async def get_transcription_status(episode_id: str):
    """Get the current transcription status for an episode."""
    db = get_database()
    episodes_collection = db.episodes

    episode = episodes_collection.find_one({"episode_id": episode_id})
    if not episode:
        raise HTTPException(status_code=404, detail=f"Episode {episode_id} not found")

    return TranscriptionStatusResponse(
        episode_id=episode_id,
        transcript_status=episode.get("transcript_status", "pending"),
        transcript_s3_key=episode.get("transcript_s3_key"),
        error_message=episode.get("error_message")
    )


@router.post("/retry/{episode_id}", response_model=TranscribeResponse)
async def retry_transcription(
    episode_id: str,
    background_tasks: BackgroundTasks
):
    """
    Retry a failed transcription.

    Resets the status and starts the workflow again.
    """
    db = get_database()
    episodes_collection = db.episodes

    episode = episodes_collection.find_one({"episode_id": episode_id})
    if not episode:
        raise HTTPException(status_code=404, detail=f"Episode {episode_id} not found")

    current_status = episode.get("transcript_status", "pending")
    if current_status == "processing":
        raise HTTPException(status_code=400, detail="Transcription is currently in progress")

    audio_url = episode.get("audio_url")
    if not audio_url:
        raise HTTPException(status_code=400, detail="No audio URL found for episode")

    # Reset status
    episodes_collection.update_one(
        {"episode_id": episode_id},
        {"$set": {"transcript_status": "pending", "error_message": None}}
    )

    # Start transcription in background
    orchestration_service = get_orchestration_service()

    async def run_transcription():
        try:
            await orchestration_service.transcribe_episode(
                episode_id=episode_id,
                audio_url=audio_url
            )
        except Exception as e:
            logger.error(f"Background transcription failed for {episode_id}: {e}")

    background_tasks.add_task(run_transcription)

    logger.info(f"Retrying transcription for episode {episode_id}")

    return TranscribeResponse(
        status="started",
        episode_id=episode_id,
        message="Transcription retry started"
    )
