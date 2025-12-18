"""
Orchestration service for transcription workflow.
Replaces AWS Step Functions with direct HTTP calls to Lambda services.
"""
import asyncio
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime

import httpx

from app.config import settings
from app.database.mongodb import MongoDB

logger = logging.getLogger(__name__)

# Timeout settings
CHUNKING_TIMEOUT = 900.0  # 15 minutes for downloading and chunking
WHISPER_TIMEOUT = 600.0   # 10 minutes per chunk transcription
MERGE_TIMEOUT = 300.0     # 5 minutes for merging


class OrchestrationService:
    """Service to orchestrate the transcription workflow."""

    def __init__(self):
        self.chunking_url = settings.chunking_lambda_url
        self.whisper_url = settings.whisper_lambda_url
        self.merge_url = settings.merge_lambda_url
        self.s3_audio_bucket = settings.s3_audio_bucket

    async def transcribe_episode(
        self,
        episode_id: str,
        audio_url: str,
        max_concurrent_transcriptions: int = 5
    ) -> Dict[str, Any]:
        """
        Orchestrate the full transcription workflow for an episode.

        Args:
            episode_id: Unique identifier for the episode
            audio_url: URL to the audio file
            max_concurrent_transcriptions: Max parallel transcription tasks

        Returns:
            Dict with status, transcript_s3_key, and any error messages
        """
        logger.info(f"Starting transcription workflow for episode {episode_id}")

        db = MongoDB.get_db()
        episodes_collection = db.episodes

        try:
            # Update status to processing
            await episodes_collection.update_one(
                {"episode_id": episode_id},
                {"$set": {"transcript_status": "processing", "updated_at": datetime.utcnow()}}
            )

            # Step 1: Download and chunk audio
            logger.info(f"Step 1: Chunking audio for episode {episode_id}")
            chunk_result = await self._call_chunking_lambda(episode_id, audio_url)

            if "error" in chunk_result:
                raise Exception(f"Chunking failed: {chunk_result['error']}")

            chunks = chunk_result.get("chunks", [])
            total_chunks = chunk_result.get("total_chunks", len(chunks))

            if not chunks:
                raise Exception("No chunks returned from chunking service")

            logger.info(f"Created {total_chunks} chunks for episode {episode_id}")

            # Step 2: Transcribe each chunk in parallel (with concurrency limit)
            logger.info(f"Step 2: Transcribing {total_chunks} chunks for episode {episode_id}")
            transcription_results = await self._transcribe_chunks_parallel(
                episode_id,
                chunks,
                max_concurrent=max_concurrent_transcriptions
            )

            # Check for failures
            failed_chunks = [r for r in transcription_results if r.get("status") == "error"]
            if failed_chunks:
                failed_indices = [r.get("chunk_index") for r in failed_chunks]
                raise Exception(f"Transcription failed for chunks: {failed_indices}")

            logger.info(f"Successfully transcribed all {total_chunks} chunks")

            # Step 3: Merge transcripts
            logger.info(f"Step 3: Merging transcripts for episode {episode_id}")
            merge_result = await self._call_merge_lambda(
                episode_id,
                total_chunks,
                transcription_results
            )

            if merge_result.get("status") == "error":
                raise Exception(f"Merge failed: {merge_result.get('error_message')}")

            transcript_s3_key = merge_result.get("transcript_s3_key")
            total_words = merge_result.get("total_words", 0)

            # Update episode with success status
            await episodes_collection.update_one(
                {"episode_id": episode_id},
                {
                    "$set": {
                        "transcript_status": "completed",
                        "transcript_s3_key": transcript_s3_key,
                        "total_words": total_words,
                        "updated_at": datetime.utcnow()
                    }
                }
            )

            logger.info(f"Transcription completed for episode {episode_id}: {total_words} words")

            return {
                "status": "completed",
                "episode_id": episode_id,
                "transcript_s3_key": transcript_s3_key,
                "total_words": total_words,
                "total_chunks": total_chunks
            }

        except Exception as e:
            error_message = str(e)
            logger.error(f"Transcription failed for episode {episode_id}: {error_message}")

            # Update episode with error status
            await episodes_collection.update_one(
                {"episode_id": episode_id},
                {
                    "$set": {
                        "transcript_status": "failed",
                        "error_message": error_message,
                        "updated_at": datetime.utcnow()
                    }
                }
            )

            return {
                "status": "failed",
                "episode_id": episode_id,
                "error_message": error_message
            }

    async def _call_chunking_lambda(
        self,
        episode_id: str,
        audio_url: str
    ) -> Dict[str, Any]:
        """Call the chunking Lambda service."""
        payload = {
            "episode_id": episode_id,
            "audio_url": audio_url,
            "s3_bucket": self.s3_audio_bucket
        }

        async with httpx.AsyncClient(timeout=CHUNKING_TIMEOUT) as client:
            response = await client.post(
                f"{self.chunking_url}/invoke",
                json=payload
            )
            response.raise_for_status()
            return response.json()

    async def _transcribe_chunks_parallel(
        self,
        episode_id: str,
        chunks: List[Dict[str, Any]],
        max_concurrent: int = 5
    ) -> List[Dict[str, Any]]:
        """Transcribe chunks in parallel with concurrency limit."""
        semaphore = asyncio.Semaphore(max_concurrent)

        async def transcribe_with_semaphore(chunk: Dict[str, Any]) -> Dict[str, Any]:
            async with semaphore:
                return await self._call_whisper_lambda(episode_id, chunk)

        tasks = [transcribe_with_semaphore(chunk) for chunk in chunks]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Convert exceptions to error results
        processed_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                processed_results.append({
                    "episode_id": episode_id,
                    "chunk_index": chunks[i].get("chunk_index", i),
                    "status": "error",
                    "error_message": str(result)
                })
            else:
                processed_results.append(result)

        return processed_results

    async def _call_whisper_lambda(
        self,
        episode_id: str,
        chunk: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Call the Whisper Lambda service for a single chunk."""
        payload = {
            "episode_id": episode_id,
            "chunk_index": chunk.get("chunk_index"),
            "s3_key": chunk.get("s3_key"),
            "start_time_seconds": chunk.get("start_time_seconds", 0),
            "s3_bucket": self.s3_audio_bucket
        }

        async with httpx.AsyncClient(timeout=WHISPER_TIMEOUT) as client:
            response = await client.post(
                f"{self.whisper_url}/invoke",
                json=payload
            )
            response.raise_for_status()
            return response.json()

    async def _call_merge_lambda(
        self,
        episode_id: str,
        total_chunks: int,
        transcription_results: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Call the merge Lambda service."""
        # Format transcripts for merge service
        transcripts = [
            {
                "chunk_index": r.get("chunk_index"),
                "transcript_s3_key": r.get("transcript_s3_key"),
                "start_time_seconds": r.get("start_time_seconds", 0)
            }
            for r in transcription_results
            if r.get("status") == "success" and r.get("transcript_s3_key")
        ]

        payload = {
            "episode_id": episode_id,
            "total_chunks": total_chunks,
            "transcripts": transcripts,
            "s3_bucket": self.s3_audio_bucket  # Transcripts are also stored in audio bucket
        }

        async with httpx.AsyncClient(timeout=MERGE_TIMEOUT) as client:
            response = await client.post(
                f"{self.merge_url}/invoke",
                json=payload
            )
            response.raise_for_status()
            return response.json()


# Singleton instance
_orchestration_service: Optional[OrchestrationService] = None


def get_orchestration_service() -> OrchestrationService:
    """Get or create the orchestration service instance."""
    global _orchestration_service
    if _orchestration_service is None:
        _orchestration_service = OrchestrationService()
    return _orchestration_service
