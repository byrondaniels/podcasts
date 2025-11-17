"""Pydantic models for request and response validation."""
from pydantic import BaseModel, Field, HttpUrl
from typing import Optional, List
from datetime import datetime
from enum import Enum


class TranscriptStatus(str, Enum):
    """Transcript processing status."""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


# Request Models
class SubscribePodcastRequest(BaseModel):
    """Request model for subscribing to a podcast."""
    rss_url: HttpUrl = Field(..., description="RSS feed URL of the podcast")


class EpisodeQueryParams(BaseModel):
    """Query parameters for episode listing."""
    status: Optional[str] = Field(None, description="Filter by transcript status (all/completed/processing)")
    page: int = Field(1, ge=1, description="Page number")
    limit: int = Field(20, ge=1, le=100, description="Number of items per page")


# Response Models
class PodcastResponse(BaseModel):
    """Response model for podcast data."""
    podcast_id: str = Field(..., description="Unique podcast identifier")
    rss_url: str = Field(..., description="RSS feed URL")
    title: str = Field(..., description="Podcast title")
    description: Optional[str] = Field(None, description="Podcast description")
    image_url: Optional[str] = Field(None, description="Podcast cover image URL")
    author: Optional[str] = Field(None, description="Podcast author")
    subscribed_at: datetime = Field(..., description="Subscription timestamp")
    active: bool = Field(True, description="Subscription status")

    class Config:
        json_schema_extra = {
            "example": {
                "podcast_id": "pod_abc123",
                "rss_url": "https://example.com/feed.rss",
                "title": "Example Podcast",
                "description": "An example podcast about technology",
                "image_url": "https://example.com/image.jpg",
                "author": "John Doe",
                "subscribed_at": "2025-01-15T10:30:00",
                "active": True
            }
        }


class PodcastListResponse(BaseModel):
    """Response model for list of podcasts."""
    podcasts: List[PodcastResponse]
    total: int


class EpisodeResponse(BaseModel):
    """Response model for episode data."""
    episode_id: str = Field(..., description="Unique episode identifier")
    podcast_id: str = Field(..., description="Parent podcast identifier")
    title: str = Field(..., description="Episode title")
    description: Optional[str] = Field(None, description="Episode description")
    audio_url: Optional[str] = Field(None, description="Original audio URL")
    published_date: Optional[datetime] = Field(None, description="Episode publication date")
    duration_minutes: Optional[int] = Field(None, description="Episode duration in minutes")
    s3_audio_key: Optional[str] = Field(None, description="S3 key for stored audio")
    transcript_status: TranscriptStatus = Field(..., description="Transcript processing status")
    transcript_s3_key: Optional[str] = Field(None, description="S3 key for transcript")
    discovered_at: datetime = Field(..., description="When episode was discovered")
    processed_at: Optional[datetime] = Field(None, description="When processing completed")

    class Config:
        json_schema_extra = {
            "example": {
                "episode_id": "ep_xyz789",
                "podcast_id": "pod_abc123",
                "title": "Episode 1: Introduction",
                "description": "Introduction to the podcast",
                "audio_url": "https://example.com/episode1.mp3",
                "published_date": "2025-01-10T08:00:00",
                "duration_minutes": 45,
                "s3_audio_key": "audio/pod_abc123/ep_xyz789.mp3",
                "transcript_status": "completed",
                "transcript_s3_key": "transcripts/pod_abc123/ep_xyz789.txt",
                "discovered_at": "2025-01-15T10:30:00",
                "processed_at": "2025-01-15T11:00:00"
            }
        }


class EpisodeListResponse(BaseModel):
    """Response model for list of episodes."""
    episodes: List[EpisodeResponse]
    total: int
    page: int
    limit: int
    has_more: bool


class TranscriptResponse(BaseModel):
    """Response model for episode transcript."""
    episode_id: str = Field(..., description="Episode identifier")
    transcript: str = Field(..., description="Transcript text")
    status: TranscriptStatus = Field(..., description="Transcript status")
    generated_at: Optional[datetime] = Field(None, description="When transcript was generated")

    class Config:
        json_schema_extra = {
            "example": {
                "episode_id": "ep_xyz789",
                "transcript": "This is the transcript of the episode...",
                "status": "completed",
                "generated_at": "2025-01-15T11:00:00"
            }
        }


class ErrorResponse(BaseModel):
    """Error response model."""
    error: str = Field(..., description="Error message")
    detail: Optional[str] = Field(None, description="Detailed error information")

    class Config:
        json_schema_extra = {
            "example": {
                "error": "Resource not found",
                "detail": "Podcast with ID 'pod_abc123' does not exist"
            }
        }


class SuccessResponse(BaseModel):
    """Generic success response."""
    message: str = Field(..., description="Success message")
    data: Optional[dict] = Field(None, description="Additional data")
