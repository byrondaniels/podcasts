"""RSS feed parser service."""
import logging
import feedparser
from typing import Dict, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class RSSParser:
    """RSS feed parser for extracting podcast information."""

    @staticmethod
    async def parse_podcast_feed(rss_url: str) -> Dict[str, Optional[str]]:
        """
        Parse RSS feed and extract podcast metadata.

        Args:
            rss_url: URL of the RSS feed

        Returns:
            Dictionary containing podcast metadata

        Raises:
            ValueError: If feed cannot be parsed or is invalid
        """
        try:
            logger.info(f"Parsing RSS feed: {rss_url}")

            # Parse the feed
            feed = feedparser.parse(rss_url)

            # Check for errors
            if feed.bozo and not feed.entries:
                error_msg = getattr(feed, 'bozo_exception', 'Unknown parsing error')
                logger.error(f"Failed to parse RSS feed: {error_msg}")
                raise ValueError(f"Invalid RSS feed: {error_msg}")

            # Check if feed has channel information
            if not hasattr(feed, 'feed'):
                raise ValueError("RSS feed does not contain channel information")

            # Extract podcast metadata
            podcast_data = {
                "title": feed.feed.get("title", "Untitled Podcast"),
                "description": feed.feed.get("description") or feed.feed.get("subtitle"),
                "image_url": RSSParser._extract_image_url(feed.feed),
                "author": feed.feed.get("author") or feed.feed.get("itunes_author"),
            }

            logger.info(f"Successfully parsed podcast: {podcast_data['title']}")
            return podcast_data

        except Exception as e:
            logger.error(f"Error parsing RSS feed {rss_url}: {e}")
            raise ValueError(f"Failed to parse RSS feed: {str(e)}")

    @staticmethod
    def _extract_image_url(feed_data: dict) -> Optional[str]:
        """
        Extract image URL from various possible feed locations.

        Args:
            feed_data: Feed data dictionary

        Returns:
            Image URL if found, None otherwise
        """
        # Try different possible locations for the image
        if hasattr(feed_data, 'image') and 'href' in feed_data.image:
            return feed_data.image.href

        if 'itunes_image' in feed_data:
            if isinstance(feed_data.itunes_image, dict):
                return feed_data.itunes_image.get('href')
            return feed_data.itunes_image

        if 'image' in feed_data and isinstance(feed_data.image, dict):
            return feed_data.image.get('url') or feed_data.image.get('href')

        return None

    @staticmethod
    async def parse_episodes(rss_url: str, limit: Optional[int] = None) -> list:
        """
        Parse RSS feed and extract episode information.

        Args:
            rss_url: URL of the RSS feed
            limit: Maximum number of episodes to return

        Returns:
            List of episode dictionaries

        Raises:
            ValueError: If feed cannot be parsed
        """
        try:
            logger.info(f"Parsing episodes from RSS feed: {rss_url}")

            feed = feedparser.parse(rss_url)

            if feed.bozo and not feed.entries:
                error_msg = getattr(feed, 'bozo_exception', 'Unknown parsing error')
                raise ValueError(f"Invalid RSS feed: {error_msg}")

            episodes = []
            entries = feed.entries[:limit] if limit else feed.entries

            for entry in entries:
                episode_data = {
                    "title": entry.get("title", "Untitled Episode"),
                    "description": entry.get("description") or entry.get("summary"),
                    "audio_url": RSSParser._extract_audio_url(entry),
                    "published_date": RSSParser._parse_published_date(entry),
                    "duration_minutes": RSSParser._extract_duration(entry),
                }
                episodes.append(episode_data)

            logger.info(f"Successfully parsed {len(episodes)} episodes")
            return episodes

        except Exception as e:
            logger.error(f"Error parsing episodes from {rss_url}: {e}")
            raise ValueError(f"Failed to parse episodes: {str(e)}")

    @staticmethod
    def _extract_audio_url(entry: dict) -> Optional[str]:
        """Extract audio URL from episode entry."""
        # Check enclosures for audio files
        if 'enclosures' in entry:
            for enclosure in entry.enclosures:
                if enclosure.get('type', '').startswith('audio/'):
                    return enclosure.get('href') or enclosure.get('url')

        # Check links
        if 'links' in entry:
            for link in entry.links:
                if link.get('type', '').startswith('audio/'):
                    return link.get('href')

        return None

    @staticmethod
    def _parse_published_date(entry: dict) -> Optional[datetime]:
        """Parse published date from episode entry."""
        date_fields = ['published_parsed', 'updated_parsed', 'created_parsed']

        for field in date_fields:
            if field in entry and entry[field]:
                try:
                    time_struct = entry[field]
                    return datetime(*time_struct[:6])
                except Exception:
                    continue

        return None

    @staticmethod
    def _extract_duration(entry: dict) -> Optional[int]:
        """Extract duration in minutes from episode entry."""
        duration = entry.get('itunes_duration')

        if not duration:
            return None

        try:
            # Duration can be in seconds or HH:MM:SS format
            if ':' in str(duration):
                parts = str(duration).split(':')
                if len(parts) == 3:  # HH:MM:SS
                    hours, minutes, seconds = map(int, parts)
                    return hours * 60 + minutes + (1 if seconds > 30 else 0)
                elif len(parts) == 2:  # MM:SS
                    minutes, seconds = map(int, parts)
                    return minutes + (1 if seconds > 30 else 0)
            else:
                # Assume seconds
                return int(int(duration) / 60)
        except Exception:
            return None


# Create singleton instance
rss_parser = RSSParser()


# Helper function for bulk transcribe service
async def parse_rss_feed(rss_url: str):
    """
    Parse RSS feed and return podcast data and episodes.

    Args:
        rss_url: URL of the RSS feed

    Returns:
        Tuple of (podcast_data, episodes)
    """
    podcast_data = await rss_parser.parse_podcast_feed(rss_url)
    episodes = await rss_parser.parse_episodes(rss_url)
    return podcast_data, episodes
