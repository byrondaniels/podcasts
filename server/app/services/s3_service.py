"""AWS S3 service for handling transcript storage and retrieval."""
import logging
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
from typing import Optional
from app.config import settings

logger = logging.getLogger(__name__)


class S3Service:
    """Service for interacting with AWS S3."""

    def __init__(self):
        """Initialize S3 client."""
        self._client = None

    @property
    def client(self):
        """Lazy initialization of S3 client."""
        if self._client is None:
            try:
                # Initialize boto3 S3 client
                client_kwargs = {
                    'region_name': settings.aws_region
                }

                # Add endpoint URL if configured (for Minio/LocalStack)
                if settings.aws_endpoint_url:
                    client_kwargs['endpoint_url'] = settings.aws_endpoint_url

                # Add credentials if provided
                if settings.aws_access_key_id and settings.aws_secret_access_key:
                    client_kwargs['aws_access_key_id'] = settings.aws_access_key_id
                    client_kwargs['aws_secret_access_key'] = settings.aws_secret_access_key

                self._client = boto3.client('s3', **client_kwargs)

                logger.info(f"S3 client initialized successfully (endpoint: {settings.aws_endpoint_url or 'default AWS'})")
            except Exception as e:
                logger.error(f"Failed to initialize S3 client: {e}")
                raise

        return self._client

    async def get_transcript(self, s3_key: str) -> Optional[str]:
        """
        Retrieve transcript from S3.

        Args:
            s3_key: S3 object key for the transcript

        Returns:
            Transcript text if found, None otherwise

        Raises:
            Exception: If there's an error retrieving the transcript
        """
        try:
            logger.info(f"Retrieving transcript from S3: {s3_key}")

            response = self.client.get_object(
                Bucket=settings.s3_bucket_name,
                Key=s3_key
            )

            # Read the transcript content
            transcript_text = response['Body'].read().decode('utf-8')

            logger.info(f"Successfully retrieved transcript: {s3_key}")
            return transcript_text

        except ClientError as e:
            error_code = e.response['Error']['Code']

            if error_code == 'NoSuchKey':
                logger.warning(f"Transcript not found in S3: {s3_key}")
                return None
            elif error_code == 'NoSuchBucket':
                logger.error(f"S3 bucket not found: {settings.s3_bucket_name}")
                raise ValueError(f"S3 bucket '{settings.s3_bucket_name}' does not exist")
            else:
                logger.error(f"S3 client error retrieving transcript: {e}")
                raise Exception(f"Failed to retrieve transcript from S3: {str(e)}")

        except NoCredentialsError:
            logger.error("AWS credentials not found")
            raise Exception("AWS credentials not configured")

        except Exception as e:
            logger.error(f"Unexpected error retrieving transcript from S3: {e}")
            raise Exception(f"Failed to retrieve transcript: {str(e)}")

    async def check_transcript_exists(self, s3_key: str) -> bool:
        """
        Check if transcript exists in S3.

        Args:
            s3_key: S3 object key for the transcript

        Returns:
            True if transcript exists, False otherwise
        """
        try:
            self.client.head_object(
                Bucket=settings.s3_bucket_name,
                Key=s3_key
            )
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                return False
            logger.error(f"Error checking transcript existence: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error checking transcript: {e}")
            return False

    async def upload_transcript(self, s3_key: str, transcript_text: str) -> bool:
        """
        Upload transcript to S3.

        Args:
            s3_key: S3 object key for the transcript
            transcript_text: Transcript content to upload

        Returns:
            True if upload successful, False otherwise
        """
        try:
            logger.info(f"Uploading transcript to S3: {s3_key}")

            self.client.put_object(
                Bucket=settings.s3_bucket_name,
                Key=s3_key,
                Body=transcript_text.encode('utf-8'),
                ContentType='text/plain'
            )

            logger.info(f"Successfully uploaded transcript: {s3_key}")
            return True

        except Exception as e:
            logger.error(f"Failed to upload transcript to S3: {e}")
            return False


# Create singleton instance
s3_service = S3Service()
