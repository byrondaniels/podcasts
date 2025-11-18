"""Service for bulk transcription of podcast episodes."""
import logging
import asyncio
from datetime import datetime
from typing import Optional, List, Dict, Any
from motor.motor_asyncio import AsyncIOMotorDatabase
from app.services.rss_parser import parse_rss_feed
from app.services.whisper_service import whisper_service
from app.models.schemas import BulkJobStatus, TranscriptStatus
import secrets

logger = logging.getLogger(__name__)


class BulkTranscribeService:
    """Service for managing bulk transcription jobs."""

    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.jobs_collection = db.bulk_transcribe_jobs
        self.episodes_collection = db.episodes
        self.running_jobs: Dict[str, bool] = {}  # Track running jobs

    async def create_job(self, rss_url: str, max_episodes: Optional[int] = None) -> Dict[str, Any]:
        """
        Create a new bulk transcription job.

        Args:
            rss_url: RSS feed URL to process
            max_episodes: Maximum number of episodes to process (None = all)

        Returns:
            Job document
        """
        try:
            logger.info(f"Creating bulk transcribe job for: {rss_url}")

            # Parse RSS feed to get episodes
            podcast_data, episodes = await parse_rss_feed(rss_url)

            if not episodes:
                raise ValueError("No episodes found in RSS feed")

            # Sort episodes by published date (oldest first for chronological processing)
            episodes.sort(key=lambda e: e.get('published_date', datetime.min))

            # Limit episodes if specified
            if max_episodes and max_episodes > 0:
                episodes = episodes[:max_episodes]

            # Create job document
            job_id = f"job_{secrets.token_urlsafe(16)}"
            job = {
                "job_id": job_id,
                "rss_url": rss_url,
                "podcast_title": podcast_data.get("title", "Unknown"),
                "status": BulkJobStatus.PENDING.value,
                "total_episodes": len(episodes),
                "processed_episodes": 0,
                "successful_episodes": 0,
                "failed_episodes": 0,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
                "completed_at": None,
                "current_episode": None,
                "episodes": [
                    {
                        "episode_id": None,  # Will be set when created
                        "title": ep.get("title", "Unknown"),
                        "audio_url": ep.get("audio_url"),
                        "status": TranscriptStatus.PENDING.value,
                        "error_message": None,
                        "started_at": None,
                        "completed_at": None,
                    }
                    for ep in episodes
                ]
            }

            # Insert job
            await self.jobs_collection.insert_one(job)
            logger.info(f"Created job {job_id} with {len(episodes)} episodes")

            return job

        except Exception as e:
            logger.error(f"Error creating bulk transcribe job: {e}")
            raise

    async def get_job(self, job_id: str) -> Optional[Dict[str, Any]]:
        """Get job by ID."""
        return await self.jobs_collection.find_one({"job_id": job_id})

    async def list_jobs(self, limit: int = 50) -> List[Dict[str, Any]]:
        """List all jobs, most recent first."""
        cursor = self.jobs_collection.find().sort("created_at", -1).limit(limit)
        return await cursor.to_list(length=limit)

    async def update_job(self, job_id: str, updates: Dict[str, Any]) -> bool:
        """Update job fields."""
        updates["updated_at"] = datetime.utcnow()
        result = await self.jobs_collection.update_one(
            {"job_id": job_id},
            {"$set": updates}
        )
        return result.modified_count > 0

    async def update_episode_in_job(
        self,
        job_id: str,
        episode_index: int,
        updates: Dict[str, Any]
    ) -> bool:
        """Update specific episode in job."""
        update_fields = {
            f"episodes.{episode_index}.{key}": value
            for key, value in updates.items()
        }
        update_fields["updated_at"] = datetime.utcnow()

        result = await self.jobs_collection.update_one(
            {"job_id": job_id},
            {"$set": update_fields}
        )
        return result.modified_count > 0

    async def process_job(self, job_id: str):
        """
        Process a bulk transcription job.
        This runs as a background task and processes episodes one at a time.
        """
        try:
            logger.info(f"Starting to process job {job_id}")

            # Mark job as running
            self.running_jobs[job_id] = True
            await self.update_job(job_id, {"status": BulkJobStatus.RUNNING.value})

            # Get job
            job = await self.get_job(job_id)
            if not job:
                logger.error(f"Job {job_id} not found")
                return

            episodes = job.get("episodes", [])

            for idx, episode_data in enumerate(episodes):
                # Check if job was cancelled
                if not self.running_jobs.get(job_id, False):
                    logger.info(f"Job {job_id} was cancelled")
                    await self.update_job(job_id, {"status": BulkJobStatus.CANCELLED.value})
                    return

                try:
                    # Update current episode
                    await self.update_job(job_id, {
                        "current_episode": episode_data.get("title")
                    })

                    # Update episode status to processing
                    await self.update_episode_in_job(job_id, idx, {
                        "status": TranscriptStatus.PROCESSING.value,
                        "started_at": datetime.utcnow()
                    })

                    logger.info(f"Processing episode {idx + 1}/{len(episodes)}: {episode_data.get('title')}")

                    # Transcribe using Whisper
                    audio_url = episode_data.get("audio_url")
                    if not audio_url:
                        raise ValueError("No audio URL found for episode")

                    transcript = await whisper_service.transcribe_audio_url(audio_url)

                    if transcript:
                        # Success - update episode and job
                        await self.update_episode_in_job(job_id, idx, {
                            "status": TranscriptStatus.COMPLETED.value,
                            "completed_at": datetime.utcnow()
                        })

                        await self.update_job(job_id, {
                            "processed_episodes": idx + 1,
                            "successful_episodes": job.get("successful_episodes", 0) + 1
                        })

                        logger.info(f"Successfully transcribed episode {idx + 1}")

                        # Store transcript (you could save to S3 or DB here)
                        # For now, just logging success

                    else:
                        # Failed - update episode and job
                        raise Exception("Transcription returned empty result")

                except Exception as e:
                    logger.error(f"Error processing episode {idx + 1}: {e}")

                    await self.update_episode_in_job(job_id, idx, {
                        "status": TranscriptStatus.FAILED.value,
                        "error_message": str(e),
                        "completed_at": datetime.utcnow()
                    })

                    await self.update_job(job_id, {
                        "processed_episodes": idx + 1,
                        "failed_episodes": job.get("failed_episodes", 0) + 1
                    })

                # Small delay between episodes to avoid overwhelming the system
                await asyncio.sleep(2)

            # Mark job as completed
            job = await self.get_job(job_id)  # Refresh job data
            final_status = BulkJobStatus.COMPLETED.value

            await self.update_job(job_id, {
                "status": final_status,
                "current_episode": None,
                "completed_at": datetime.utcnow()
            })

            logger.info(
                f"Job {job_id} completed. "
                f"Success: {job.get('successful_episodes', 0)}, "
                f"Failed: {job.get('failed_episodes', 0)}"
            )

        except Exception as e:
            logger.error(f"Error processing job {job_id}: {e}")
            await self.update_job(job_id, {
                "status": BulkJobStatus.FAILED.value,
                "current_episode": None
            })
        finally:
            # Clean up running jobs tracker
            if job_id in self.running_jobs:
                del self.running_jobs[job_id]

    async def cancel_job(self, job_id: str) -> bool:
        """Cancel a running job."""
        if job_id in self.running_jobs:
            self.running_jobs[job_id] = False
            logger.info(f"Cancelled job {job_id}")
            return True
        return False
