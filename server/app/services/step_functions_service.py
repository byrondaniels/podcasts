"""Service for interacting with AWS Step Functions."""
import logging
import json
import time
from typing import Dict, Any
import boto3
from botocore.exceptions import ClientError

from app.config import settings

logger = logging.getLogger(__name__)


class StepFunctionsService:
    """Service for triggering Step Functions state machine executions."""

    def __init__(self):
        """Initialize Step Functions client."""
        # Configure boto3 client
        client_config = {
            "region_name": settings.aws_region
        }

        # Use LocalStack endpoint if configured (for dev)
        if settings.aws_endpoint_url:
            client_config["endpoint_url"] = settings.aws_endpoint_url
            client_config["aws_access_key_id"] = settings.aws_access_key_id or "test"
            client_config["aws_secret_access_key"] = settings.aws_secret_access_key or "test"
        else:
            # Production: use real AWS credentials if provided
            if settings.aws_access_key_id and settings.aws_secret_access_key:
                client_config["aws_access_key_id"] = settings.aws_access_key_id
                client_config["aws_secret_access_key"] = settings.aws_secret_access_key

        self.sfn_client = boto3.client("stepfunctions", **client_config)

    async def trigger_transcription(
        self,
        episode_id: str,
        audio_url: str,
        s3_bucket: str = None
    ) -> Dict[str, Any]:
        """
        Trigger Step Functions state machine for episode transcription.

        Args:
            episode_id: ID of the episode to transcribe
            audio_url: URL of the audio file
            s3_bucket: S3 bucket name (optional, uses default if not provided)

        Returns:
            Dict containing execution ARN and start date

        Raises:
            ValueError: If Step Function ARN is not configured
            ClientError: If Step Functions execution fails
        """
        if not settings.step_function_arn:
            raise ValueError(
                "STEP_FUNCTION_ARN environment variable not configured. "
                "Cannot trigger transcription."
            )

        # Use default S3 bucket if not provided
        if not s3_bucket:
            s3_bucket = settings.s3_bucket_name

        # Prepare input for Step Functions
        step_input = {
            "episode_id": episode_id,
            "audio_url": audio_url,
            "s3_bucket": s3_bucket
        }

        # Generate unique execution name
        execution_name = f"episode-{episode_id}-{int(time.time())}"

        try:
            logger.info(
                f"Triggering Step Functions execution for episode {episode_id}"
            )
            logger.debug(f"Step Functions input: {step_input}")

            # Start Step Functions execution
            response = self.sfn_client.start_execution(
                stateMachineArn=settings.step_function_arn,
                name=execution_name,
                input=json.dumps(step_input)
            )

            logger.info(
                f"Successfully started Step Functions execution: {response['executionArn']}"
            )

            return {
                "execution_arn": response["executionArn"],
                "start_date": response["startDate"].isoformat()
            }

        except ClientError as e:
            logger.error(f"Failed to start Step Functions execution: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error triggering Step Functions: {e}")
            raise


# Create singleton instance
step_functions_service = StepFunctionsService()
