"""Service for local Whisper transcription."""
import logging
import aiohttp
import tempfile
from pathlib import Path
from typing import Optional
from app.config import settings

logger = logging.getLogger(__name__)


class WhisperService:
    """Service for transcribing audio using local Whisper container."""

    def __init__(self):
        self.whisper_url = settings.whisper_service_url.rstrip('/')
        self.transcribe_endpoint = f"{self.whisper_url}/asr"

    async def transcribe_audio_file(self, audio_path: Path) -> Optional[str]:
        """
        Transcribe an audio file using the local Whisper service.

        Args:
            audio_path: Path to the audio file to transcribe

        Returns:
            Transcribed text or None if transcription fails
        """
        try:
            logger.info(f"Transcribing audio file: {audio_path}")

            # Prepare the file for upload
            async with aiohttp.ClientSession() as session:
                with open(audio_path, 'rb') as audio_file:
                    form_data = aiohttp.FormData()
                    form_data.add_field(
                        'audio_file',
                        audio_file,
                        filename=audio_path.name,
                        content_type='audio/mpeg'
                    )
                    form_data.add_field('task', 'transcribe')
                    form_data.add_field('language', 'en')
                    form_data.add_field('output', 'txt')

                    # Send request to Whisper service
                    async with session.post(
                        self.transcribe_endpoint,
                        data=form_data,
                        timeout=aiohttp.ClientTimeout(total=3600)  # 1 hour timeout
                    ) as response:
                        if response.status == 200:
                            transcript = await response.text()
                            logger.info(f"Successfully transcribed {audio_path.name}")
                            return transcript.strip()
                        else:
                            error_text = await response.text()
                            logger.error(
                                f"Whisper service returned status {response.status}: {error_text}"
                            )
                            return None

        except aiohttp.ClientError as e:
            logger.error(f"Network error during transcription: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error during transcription: {e}")
            return None

    async def transcribe_audio_url(self, audio_url: str) -> Optional[str]:
        """
        Download and transcribe audio from a URL.

        Args:
            audio_url: URL of the audio file to transcribe

        Returns:
            Transcribed text or None if transcription fails
        """
        temp_file = None
        try:
            logger.info(f"Downloading audio from: {audio_url}")

            # Download the audio file
            async with aiohttp.ClientSession() as session:
                async with session.get(audio_url, timeout=aiohttp.ClientTimeout(total=600)) as response:
                    if response.status != 200:
                        logger.error(f"Failed to download audio: HTTP {response.status}")
                        return None

                    # Save to temporary file
                    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as temp_file:
                        while True:
                            chunk = await response.content.read(8192)
                            if not chunk:
                                break
                            temp_file.write(chunk)
                        temp_path = Path(temp_file.name)

            logger.info(f"Audio downloaded to: {temp_path}")

            # Transcribe the downloaded file
            transcript = await self.transcribe_audio_file(temp_path)

            return transcript

        except Exception as e:
            logger.error(f"Error downloading/transcribing audio: {e}")
            return None
        finally:
            # Clean up temporary file
            if temp_file and Path(temp_file.name).exists():
                try:
                    Path(temp_file.name).unlink()
                    logger.debug(f"Cleaned up temporary file: {temp_file.name}")
                except Exception as e:
                    logger.warning(f"Failed to delete temporary file: {e}")

    async def health_check(self) -> bool:
        """
        Check if the Whisper service is available.

        Returns:
            True if service is healthy, False otherwise
        """
        try:
            health_url = f"{self.whisper_url}/health"
            async with aiohttp.ClientSession() as session:
                async with session.get(health_url, timeout=aiohttp.ClientTimeout(total=5)) as response:
                    return response.status == 200
        except Exception as e:
            logger.error(f"Whisper service health check failed: {e}")
            return False


# Singleton instance
whisper_service = WhisperService()
