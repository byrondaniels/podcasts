"""Lambda service for triggering Lambda functions via HTTP."""
import logging
from typing import Optional, Dict, Any
import httpx
from app.config import settings

logger = logging.getLogger(__name__)


class LambdaService:
    """Service for interacting with Lambda HTTP services."""

    def __init__(self):
        """Initialize Lambda service."""
        self.poll_lambda_url = settings.poll_lambda_url

    async def invoke_poll_lambda(self, podcast_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Invoke the RSS polling Lambda function via HTTP.

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

            # Invoke the Lambda function via HTTP
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    f"{self.poll_lambda_url}/invoke",
                    json=payload
                )
                response.raise_for_status()
                response_payload = response.json()

            logger.info(f"Poll Lambda invoked successfully. Response: {response_payload}")
            return response_payload

        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error invoking poll Lambda: {e.response.status_code} - {e.response.text}")
            raise Exception(f"Failed to invoke poll Lambda: HTTP {e.response.status_code}")

        except Exception as e:
            logger.error(f"Unexpected error invoking poll Lambda: {e}")
            raise Exception(f"Failed to invoke poll Lambda: {str(e)}")


# Create singleton instance
lambda_service = LambdaService()
