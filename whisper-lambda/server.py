"""
HTTP server wrapper for Whisper Lambda function.
Exposes the Lambda handler as an HTTP endpoint for local Docker development.
"""
import json
import logging
import os
import sys
import traceback
from flask import Flask, request, jsonify

# Add lambda directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lambda'))

# Import the Lambda handler
from handler import lambda_handler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy", "service": "whisper-lambda"})


@app.route('/invoke', methods=['POST'])
def invoke():
    """
    Invoke the Lambda handler with the provided event payload.

    Expected POST body (same as Lambda event):
    {
        "episode_id": "string",
        "chunk_index": int,
        "s3_key": "string",
        "start_time_seconds": int,
        "s3_bucket": "string"
    }

    Returns the Lambda handler response.
    """
    try:
        # Get the event payload from request body
        event = request.get_json()

        if not event:
            return jsonify({
                "error": "Missing request body",
                "status": "error"
            }), 400

        logger.info(f"Received invoke request: {json.dumps(event)}")

        # Call the Lambda handler (context can be None for HTTP mode)
        result = lambda_handler(event, None)

        logger.info(f"Lambda handler returned: {json.dumps(result)}")

        return jsonify(result)

    except ValueError as e:
        error_msg = f"Validation error: {str(e)}"
        logger.error(error_msg)
        return jsonify({
            "error": error_msg,
            "status": "error"
        }), 400

    except Exception as e:
        error_msg = f"Internal error: {str(e)}"
        logger.error(f"{error_msg}\n{traceback.format_exc()}")
        return jsonify({
            "error": error_msg,
            "status": "error",
            "traceback": traceback.format_exc()
        }), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8003))
    logger.info(f"Starting whisper-lambda HTTP server on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
