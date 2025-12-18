"""Application configuration module."""
from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    """Application settings."""

    # MongoDB Configuration
    mongodb_url: str = "mongodb://localhost:27017"
    mongodb_db_name: str = "podcast_manager"

    # AWS S3 Configuration
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_region: str = "us-east-1"
    aws_endpoint_url: str = ""  # For LocalStack in dev
    s3_bucket_name: str = "podcast-transcripts"

    # AWS Step Functions Configuration (deprecated - using Lambda HTTP services)
    step_function_arn: str = ""

    # Lambda HTTP Service URLs (for local Docker orchestration)
    poll_lambda_url: str = "http://poll-lambda:8001"
    chunking_lambda_url: str = "http://chunking-lambda:8002"
    whisper_lambda_url: str = "http://whisper-lambda:8003"
    merge_lambda_url: str = "http://merge-lambda:8004"

    # S3 Audio Bucket (separate from transcripts bucket)
    s3_audio_bucket: str = "podcast-audio"

    # Transcription Configuration
    openai_api_key: str = ""
    whisper_service_url: str = "http://localhost:9000"

    # Application Configuration
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    log_level: str = "INFO"

    # CORS Configuration
    cors_origins: str = "http://localhost:3000,http://localhost:8080"

    @property
    def cors_origins_list(self) -> List[str]:
        """Parse CORS origins from comma-separated string."""
        return [origin.strip() for origin in self.cors_origins.split(",")]

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
