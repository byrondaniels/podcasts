"""RSS feed parser service."""
import logging
import asyncio
import feedparser
import aiohttp
from typing import Dict, Optional
from datetime import datetime

logger = logging.getLogger(__name__)

# RSS feed fetch timeout in seconds
RSS_FETCH_TIMEOUT = 10


class RSSParser:
    """RSS feed parser for extracting podcast information."""

    @staticmethod
    async def _fetch_rss_content(rss_url: str) -> str:
        """
        Fetch RSS feed content with timeout.

        Args:
            rss_url: URL of the RSS feed

        Returns:
            RSS feed content as string

        Raises:
            ValueError: If feed cannot be fetched or times out
        """
        try:
            logger.info(f"Fetching RSS feed from: {rss_url}")
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    rss_url,
                    timeout=aiohttp.ClientTimeout(total=RSS_FETCH_TIMEOUT)
                ) as response:
                    if response.status != 200:
                        raise ValueError(f"HTTP {response.status}: Failed to fetch RSS feed")

                    content = await response.text()
                    logger.info(f"Successfully fetched RSS feed ({len(content)} bytes)")
                    return content

        except asyncio.TimeoutError:
            logger.error(f"Timeout fetching RSS feed from {rss_url}")
            raise ValueError(f"Request timeout: RSS feed took longer than {RSS_FETCH_TIMEOUT} seconds to respond")
        except aiohttp.ClientError as e:
            logger.error(f"Network error fetching RSS feed: {e}")
            raise ValueError(f"Network error: {str(e)}")
        except Exception as e:
            logger.error(f"Error fetching RSS feed from {rss_url}: {e}")
            raise ValueError(f"Failed to fetch RSS feed: {str(e)}")

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

            # Fetch RSS content with timeout
            content = await RSSParser._fetch_rss_content(rss_url)

            # Parse the feed from content
            feed = feedparser.parse(content)

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

        except ValueError:
            # Re-raise ValueError as-is (includes our timeout and HTTP errors)
            raise
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

            # Fetch RSS content with timeout
            content = await RSSParser._fetch_rss_content(rss_url)

            # Parse the feed from content
            feed = feedparser.parse(content)

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

        except ValueError:
            # Re-raise ValueError as-is (includes our timeout and HTTP errors)
            raise
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
    Optimized to fetch the feed only once.

    Args:
        rss_url: URL of the RSS feed

    Returns:
        Tuple of (podcast_data, episodes)
    """
    # Fetch RSS content once with timeout
    content = await rss_parser._fetch_rss_content(rss_url)

    # Parse the content for both podcast data and episodes
    feed = feedparser.parse(content)

    # Check for errors
    if feed.bozo and not feed.entries:
        error_msg = getattr(feed, 'bozo_exception', 'Unknown parsing error')
        raise ValueError(f"Invalid RSS feed: {error_msg}")

    # Check if feed has channel information
    if not hasattr(feed, 'feed'):
        raise ValueError("RSS feed does not contain channel information")

    # Extract podcast metadata
    podcast_data = {
        "title": feed.feed.get("title", "Untitled Podcast"),
        "description": feed.feed.get("description") or feed.feed.get("subtitle"),
        "image_url": rss_parser._extract_image_url(feed.feed),
        "author": feed.feed.get("author") or feed.feed.get("itunes_author"),
    }

    # Extract episodes
    episodes = []
    for entry in feed.entries:
        episode_data = {
            "title": entry.get("title", "Untitled Episode"),
            "description": entry.get("description") or entry.get("summary"),
            "audio_url": rss_parser._extract_audio_url(entry),
            "published_date": rss_parser._parse_published_date(entry),
            "duration_minutes": rss_parser._extract_duration(entry),
        }
        episodes.append(episode_data)

    logger.info(f"Successfully parsed podcast '{podcast_data['title']}' with {len(episodes)} episodes")
    return podcast_data, episodes
