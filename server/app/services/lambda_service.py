"""AWS Lambda service for triggering Lambda functions."""
import logging
import json
import boto3
from botocore.exceptions import ClientError
from typing import Optional, Dict, Any
from app.config import settings

logger = logging.getLogger(__name__)


class LambdaService:
    """Service for interacting with AWS Lambda."""

    def __init__(self):
        """Initialize Lambda client."""
        self._client = None

    @property
    def client(self):
        """Lazy initialization of Lambda client."""
        if self._client is None:
            try:
                # Initialize boto3 Lambda client
                if settings.aws_access_key_id and settings.aws_secret_access_key:
                    self._client = boto3.client(
                        'lambda',
                        aws_access_key_id=settings.aws_access_key_id,
                        aws_secret_access_key=settings.aws_secret_access_key,
                        region_name=settings.aws_region
                    )
                else:
                    # Use default credentials (IAM role, environment variables, etc.)
                    self._client = boto3.client('lambda', region_name=settings.aws_region)

                logger.info("Lambda client initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Lambda client: {e}")
                raise

        return self._client

    async def invoke_poll_lambda(self, podcast_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Invoke the RSS polling Lambda function.

        Args:
            podcast_id: Optional podcast ID to poll specific podcast.
                       If None, polls all active podcasts.

        Returns:
            Lambda response payload

        Raises:
            Exception: If there's an error invoking the Lambda
        """
        try:
            # Build the payload
            payload = {}
            if podcast_id:
                payload["podcast_id"] = podcast_id
                logger.info(f"Invoking poll Lambda for podcast: {podcast_id}")
            else:
                logger.info("Invoking poll Lambda for all podcasts")

            # Invoke the Lambda function
            response = self.client.invoke(
                FunctionName='poll-rss-feeds',
                InvocationType='RequestResponse',  # Synchronous invocation
                Payload=json.dumps(payload).encode('utf-8')
            )

            # Parse the response
            response_payload = json.loads(response['Payload'].read().decode('utf-8'))

            logger.info(f"Poll Lambda invoked successfully. Response: {response_payload}")
            return response_payload

        except ClientError as e:
            error_code = e.response['Error']['Code']
            logger.error(f"Lambda client error: {error_code} - {e}")
            raise Exception(f"Failed to invoke poll Lambda: {str(e)}")

        except Exception as e:
            logger.error(f"Unexpected error invoking poll Lambda: {e}")
            raise Exception(f"Failed to invoke poll Lambda: {str(e)}")


# Create singleton instance
lambda_service = LambdaService()
