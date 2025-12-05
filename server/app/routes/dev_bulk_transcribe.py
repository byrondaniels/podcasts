"""Dev-only routes for bulk podcast transcription."""
import logging
from fastapi import APIRouter, HTTPException, BackgroundTasks
from typing import List
from app.database.mongodb import get_database
from app.models.schemas import (
    BulkTranscribeRequest,
    BulkTranscribeJobResponse,
    BulkTranscribeJobListResponse,
    BulkTranscribeEpisodeProgress,
    BulkJobStatus,
    SuccessResponse
)
from app.services.bulk_transcribe_service import BulkTranscribeService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/dev", tags=["dev-bulk-transcribe"])


@router.post("/bulk-transcribe", response_model=BulkTranscribeJobResponse)
async def start_bulk_transcribe(
    request: BulkTranscribeRequest,
    background_tasks: BackgroundTasks
):
    """
    Start a bulk transcription job for all episodes in an RSS feed.
    This endpoint is dev-only and uses the local Whisper container.
    """
    try:
        db = await get_database()
        service = BulkTranscribeService(db)

        # Create job
        job = await service.create_job(
            rss_url=str(request.rss_url),
            max_episodes=request.max_episodes,
            dry_run=request.dry_run
        )

        # Start processing in background
        background_tasks.add_task(service.process_job, job["job_id"])

        # Convert episodes to response model
        episodes_progress = [
            BulkTranscribeEpisodeProgress(
                episode_id=ep.get("episode_id", ""),
                title=ep["title"],
                status=ep["status"],
                transcript=ep.get("transcript"),
                error_message=ep.get("error_message"),
                started_at=ep.get("started_at"),
                completed_at=ep.get("completed_at")
            )
            for ep in job.get("episodes", [])
        ]

        return BulkTranscribeJobResponse(
            job_id=job["job_id"],
            rss_url=job["rss_url"],
            status=BulkJobStatus(job["status"]),
            total_episodes=job["total_episodes"],
            processed_episodes=job["processed_episodes"],
            successful_episodes=job["successful_episodes"],
            failed_episodes=job["failed_episodes"],
            created_at=job["created_at"],
            updated_at=job["updated_at"],
            completed_at=job.get("completed_at"),
            current_episode=job.get("current_episode"),
            episodes=episodes_progress
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error starting bulk transcribe job: {e}")
        raise HTTPException(status_code=500, detail="Failed to start bulk transcription job")


@router.get("/bulk-transcribe/{job_id}", response_model=BulkTranscribeJobResponse)
async def get_bulk_transcribe_job(job_id: str):
    """Get the status and progress of a bulk transcription job."""
    try:
        db = await get_database()
        service = BulkTranscribeService(db)

        job = await service.get_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        # Convert episodes to response model
        episodes_progress = [
            BulkTranscribeEpisodeProgress(
                episode_id=ep.get("episode_id", ""),
                title=ep["title"],
                status=ep["status"],
                transcript=ep.get("transcript"),
                error_message=ep.get("error_message"),
                started_at=ep.get("started_at"),
                completed_at=ep.get("completed_at")
            )
            for ep in job.get("episodes", [])
        ]

        return BulkTranscribeJobResponse(
            job_id=job["job_id"],
            rss_url=job["rss_url"],
            status=BulkJobStatus(job["status"]),
            total_episodes=job["total_episodes"],
            processed_episodes=job["processed_episodes"],
            successful_episodes=job["successful_episodes"],
            failed_episodes=job["failed_episodes"],
            created_at=job["created_at"],
            updated_at=job["updated_at"],
            completed_at=job.get("completed_at"),
            current_episode=job.get("current_episode"),
            episodes=episodes_progress
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting bulk transcribe job: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve job")


@router.get("/bulk-transcribe", response_model=BulkTranscribeJobListResponse)
async def list_bulk_transcribe_jobs(limit: int = 50):
    """List all bulk transcription jobs."""
    try:
        db = await get_database()
        service = BulkTranscribeService(db)

        jobs = await service.list_jobs(limit=limit)

        job_responses = [
            BulkTranscribeJobResponse(
                job_id=job["job_id"],
                rss_url=job["rss_url"],
                status=BulkJobStatus(job["status"]),
                total_episodes=job["total_episodes"],
                processed_episodes=job["processed_episodes"],
                successful_episodes=job["successful_episodes"],
                failed_episodes=job["failed_episodes"],
                created_at=job["created_at"],
                updated_at=job["updated_at"],
                completed_at=job.get("completed_at"),
                current_episode=job.get("current_episode"),
                episodes=None  # Don't include full episode list in listing
            )
            for job in jobs
        ]

        return BulkTranscribeJobListResponse(
            jobs=job_responses,
            total=len(job_responses)
        )

    except Exception as e:
        logger.error(f"Error listing bulk transcribe jobs: {e}")
        raise HTTPException(status_code=500, detail="Failed to list jobs")


@router.post("/bulk-transcribe/{job_id}/cancel", response_model=SuccessResponse)
async def cancel_bulk_transcribe_job(job_id: str):
    """Cancel a running bulk transcription job."""
    try:
        db = await get_database()
        service = BulkTranscribeService(db)

        # Check if job exists
        job = await service.get_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        # Try to cancel
        cancelled = await service.cancel_job(job_id)

        return SuccessResponse(
            message="Job cancellation requested" if cancelled else "Job is not running",
            data={"job_id": job_id, "cancelled": cancelled}
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error cancelling job: {e}")
        raise HTTPException(status_code=500, detail="Failed to cancel job")
