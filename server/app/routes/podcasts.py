"""Podcast management endpoints."""
import logging
import uuid
from datetime import datetime
from fastapi import APIRouter, HTTPException, Depends, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo.errors import DuplicateKeyError

from app.database import get_database
from app.models import (
    SubscribePodcastRequest,
    PodcastResponse,
    PodcastListResponse,
    SuccessResponse,
)
from app.services import rss_parser

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/podcasts", tags=["podcasts"])


@router.post("/subscribe", response_model=PodcastResponse, status_code=status.HTTP_201_CREATED)
async def subscribe_to_podcast(
    request: SubscribePodcastRequest,
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """
    Subscribe to a podcast by RSS feed URL.

    This endpoint:
    1. Parses the RSS feed to extract podcast metadata
    2. Saves the podcast to the database
    3. Returns the podcast details

    Args:
        request: Subscribe request containing RSS feed URL
        db: Database instance

    Returns:
        Podcast details

    Raises:
        HTTPException: If RSS feed is invalid or already subscribed
    """
    try:
        rss_url = str(request.rss_url)
        logger.info(f"Subscribing to podcast: {rss_url}")

        # Check if already subscribed
        existing_podcast = await db.podcasts.find_one({"rss_url": rss_url})
        if existing_podcast:
            # If podcast exists but is inactive, reactivate it
            if not existing_podcast.get("active", True):
                await db.podcasts.update_one(
                    {"rss_url": rss_url},
                    {"$set": {"active": True, "subscribed_at": datetime.utcnow()}}
                )
                logger.info(f"Reactivated podcast: {existing_podcast['podcast_id']}")

                # Fetch updated podcast
                updated_podcast = await db.podcasts.find_one({"rss_url": rss_url})
                return _format_podcast_response(updated_podcast)
            else:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Already subscribed to this podcast"
                )

        # Parse RSS feed to get podcast metadata and episode count
        try:
            # Use the optimized parser that fetches the feed once
            from app.services.rss_parser import parse_rss_feed
            podcast_data, episodes = await parse_rss_feed(rss_url)
            episode_count = len(episodes)
            logger.info(f"Found {episode_count} episodes in RSS feed")
        except ValueError as e:
            logger.error(f"Failed to parse RSS feed: {e}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid RSS feed: {str(e)}"
            )

        # Generate podcast ID
        podcast_id = f"pod_{uuid.uuid4().hex[:12]}"

        # Create podcast document
        podcast_doc = {
            "podcast_id": podcast_id,
            "rss_url": rss_url,
            "title": podcast_data["title"],
            "description": podcast_data["description"],
            "image_url": podcast_data["image_url"],
            "author": podcast_data["author"],
            "subscribed_at": datetime.utcnow(),
            "active": True,
            "episode_count": episode_count,
        }

        # Insert into database
        try:
            await db.podcasts.insert_one(podcast_doc)
            logger.info(f"Successfully subscribed to podcast: {podcast_id}")
        except DuplicateKeyError:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Podcast with this RSS URL already exists"
            )

        return _format_podcast_response(podcast_doc)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error subscribing to podcast: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to subscribe to podcast"
        )


@router.get("", response_model=PodcastListResponse)
async def get_podcasts(
    active_only: bool = True,
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """
    Get all subscribed podcasts.

    Args:
        active_only: If True, only return active subscriptions
        db: Database instance

    Returns:
        List of podcasts with metadata
    """
    try:
        logger.info(f"Fetching podcasts (active_only={active_only})")

        # Build query
        query = {"active": True} if active_only else {}

        # Fetch podcasts sorted by subscription date (newest first)
        cursor = db.podcasts.find(query).sort("subscribed_at", -1)
        podcasts = await cursor.to_list(length=None)

        logger.info(f"Found {len(podcasts)} podcasts")

        return {
            "podcasts": [_format_podcast_response(p) for p in podcasts],
            "total": len(podcasts)
        }

    except Exception as e:
        logger.error(f"Error fetching podcasts: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch podcasts"
        )


@router.delete("/{podcast_id}", response_model=SuccessResponse)
async def unsubscribe_from_podcast(
    podcast_id: str,
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    """
    Unsubscribe from a podcast.

    This marks the podcast as inactive but doesn't delete episodes or transcripts.

    Args:
        podcast_id: ID of the podcast to unsubscribe from
        db: Database instance

    Returns:
        Success message

    Raises:
        HTTPException: If podcast not found
    """
    try:
        logger.info(f"Unsubscribing from podcast: {podcast_id}")

        # Check if podcast exists
        podcast = await db.podcasts.find_one({"podcast_id": podcast_id})
        if not podcast:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Podcast with ID '{podcast_id}' not found"
            )

        # Mark as inactive
        result = await db.podcasts.update_one(
            {"podcast_id": podcast_id},
            {"$set": {"active": False}}
        )

        if result.modified_count == 0:
            logger.warning(f"Podcast {podcast_id} was already inactive")

        logger.info(f"Successfully unsubscribed from podcast: {podcast_id}")

        return {
            "message": f"Successfully unsubscribed from podcast '{podcast['title']}'",
            "data": {"podcast_id": podcast_id}
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error unsubscribing from podcast: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to unsubscribe from podcast"
        )


def _format_podcast_response(podcast_doc: dict) -> PodcastResponse:
    """Format podcast document as response model."""
    return PodcastResponse(
        podcast_id=podcast_doc["podcast_id"],
        rss_url=podcast_doc["rss_url"],
        title=podcast_doc["title"],
        description=podcast_doc.get("description"),
        image_url=podcast_doc.get("image_url"),
        author=podcast_doc.get("author"),
        subscribed_at=podcast_doc["subscribed_at"],
        active=podcast_doc.get("active", True),
        episode_count=podcast_doc.get("episode_count"),
    )
