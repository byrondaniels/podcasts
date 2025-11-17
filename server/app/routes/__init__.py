"""Routes package."""
from .podcasts import router as podcasts_router
from .episodes import router as episodes_router

__all__ = ["podcasts_router", "episodes_router"]
