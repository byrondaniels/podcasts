"""Routes package."""
from .podcasts import router as podcasts_router
from .episodes import router as episodes_router
from .dev_bulk_transcribe import router as dev_bulk_transcribe_router
from .transcription import router as transcription_router

__all__ = [
    "podcasts_router",
    "episodes_router",
    "dev_bulk_transcribe_router",
    "transcription_router"
]
