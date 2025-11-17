"""MongoDB database connection and utilities."""
import logging
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from typing import Optional
from app.config import settings

logger = logging.getLogger(__name__)


class MongoDB:
    """MongoDB connection manager."""

    client: Optional[AsyncIOMotorClient] = None
    db: Optional[AsyncIOMotorDatabase] = None

    @classmethod
    async def connect_db(cls):
        """Connect to MongoDB."""
        try:
            logger.info(f"Connecting to MongoDB at {settings.mongodb_url}")
            cls.client = AsyncIOMotorClient(settings.mongodb_url)
            cls.db = cls.client[settings.mongodb_db_name]

            # Create indexes
            await cls._create_indexes()

            # Test connection
            await cls.client.admin.command('ping')
            logger.info("Successfully connected to MongoDB")
        except Exception as e:
            logger.error(f"Failed to connect to MongoDB: {e}")
            raise

    @classmethod
    async def _create_indexes(cls):
        """Create database indexes for optimal performance."""
        try:
            # Podcasts collection indexes
            await cls.db.podcasts.create_index("podcast_id", unique=True)
            await cls.db.podcasts.create_index("rss_url", unique=True)
            await cls.db.podcasts.create_index([("active", 1), ("subscribed_at", -1)])

            # Episodes collection indexes
            await cls.db.episodes.create_index("episode_id", unique=True)
            await cls.db.episodes.create_index("podcast_id")
            await cls.db.episodes.create_index([("podcast_id", 1), ("published_date", -1)])
            await cls.db.episodes.create_index("transcript_status")
            await cls.db.episodes.create_index([("published_date", -1)])

            logger.info("Database indexes created successfully")
        except Exception as e:
            logger.warning(f"Error creating indexes: {e}")

    @classmethod
    async def close_db(cls):
        """Close MongoDB connection."""
        if cls.client:
            cls.client.close()
            logger.info("MongoDB connection closed")

    @classmethod
    def get_db(cls) -> AsyncIOMotorDatabase:
        """Get database instance."""
        if cls.db is None:
            raise RuntimeError("Database not initialized. Call connect_db first.")
        return cls.db


# Convenience function for dependency injection
async def get_database() -> AsyncIOMotorDatabase:
    """FastAPI dependency for getting database instance."""
    return MongoDB.get_db()
