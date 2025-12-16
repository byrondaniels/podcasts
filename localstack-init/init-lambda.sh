#!/bin/bash
# LocalStack Lambda Initialization Script
# This script creates/updates Lambda functions, S3 buckets, and Step Functions
set -e

echo "============================================"
echo "Initializing LocalStack for Podcast App..."
echo "============================================"

# Wait for LocalStack to be ready
echo "Waiting for LocalStack..."
until awslocal s3 ls 2>/dev/null; do
    echo "  Waiting for S3..."
    sleep 2
done
echo "LocalStack is ready!"

# Helper function to create or update Lambda
create_or_update_lambda() {
    local FUNC_NAME="$1"
    local RUNTIME="$2"
    local HANDLER="$3"
    local ZIP_FILE="$4"
    local ENV_VARS="$5"
    local TIMEOUT="${6:-300}"
    local MEMORY="${7:-512}"

    echo "  Processing Lambda: $FUNC_NAME"

    # Check if function exists
    if awslocal lambda get-function --function-name "$FUNC_NAME" 2>/dev/null; then
        echo "    Updating existing function..."
        awslocal lambda update-function-code \
            --function-name "$FUNC_NAME" \
            --zip-file "fileb://$ZIP_FILE" \
            > /dev/null

        awslocal lambda update-function-configuration \
            --function-name "$FUNC_NAME" \
            --timeout "$TIMEOUT" \
            --memory-size "$MEMORY" \
            --environment "$ENV_VARS" \
            > /dev/null
        echo "    Updated: $FUNC_NAME"
    else
        echo "    Creating new function..."
        awslocal lambda create-function \
            --function-name "$FUNC_NAME" \
            --runtime "$RUNTIME" \
            --role "arn:aws:iam::000000000000:role/lambda-role" \
            --handler "$HANDLER" \
            --zip-file "fileb://$ZIP_FILE" \
            --timeout "$TIMEOUT" \
            --memory-size "$MEMORY" \
            --environment "$ENV_VARS" \
            > /dev/null
        echo "    Created: $FUNC_NAME"
    fi
}

# Create S3 buckets
echo ""
echo "Creating S3 buckets..."
awslocal s3 mb s3://podcast-audio 2>/dev/null || echo "  Bucket podcast-audio already exists"
awslocal s3 mb s3://podcast-transcripts 2>/dev/null || echo "  Bucket podcast-transcripts already exists"
echo "  S3 buckets ready"

# Build Go Lambda zip files from bootstrap if needed
echo ""
echo "Preparing Lambda packages..."

# Poll Lambda (Go)
if [ -f /tmp/lambda/poll-lambda/bootstrap ]; then
    echo "  Creating poll-lambda.zip..."
    cd /tmp/lambda/poll-lambda
    rm -f function.zip
    zip -q function.zip bootstrap
    POLL_ZIP="/tmp/lambda/poll-lambda/function.zip"
elif [ -f /tmp/lambda/poll-lambda-go.zip ]; then
    POLL_ZIP="/tmp/lambda/poll-lambda-go.zip"
else
    echo "  WARNING: Poll Lambda not found!"
    POLL_ZIP=""
fi

# Merge Lambda (Go)
if [ -f /tmp/lambda/merge-lambda/bootstrap ]; then
    echo "  Creating merge-lambda.zip..."
    cd /tmp/lambda/merge-lambda
    rm -f function.zip
    zip -q function.zip bootstrap
    MERGE_ZIP="/tmp/lambda/merge-lambda/function.zip"
elif [ -f /tmp/lambda/merge-lambda-go.zip ]; then
    MERGE_ZIP="/tmp/lambda/merge-lambda-go.zip"
else
    echo "  WARNING: Merge Lambda not found!"
    MERGE_ZIP=""
fi

# Chunking Lambda (Python)
if [ -f /tmp/lambda/chunking-lambda.zip ]; then
    CHUNKING_ZIP="/tmp/lambda/chunking-lambda.zip"
else
    echo "  WARNING: Chunking Lambda not found!"
    CHUNKING_ZIP=""
fi

# Whisper Lambda (Python)
if [ -f /tmp/lambda/whisper-lambda.zip ]; then
    WHISPER_ZIP="/tmp/lambda/whisper-lambda.zip"
else
    echo "  WARNING: Whisper Lambda not found!"
    WHISPER_ZIP=""
fi

# Create/Update Lambda functions
echo ""
echo "Creating/Updating Lambda functions..."

# Poll Lambda (Go)
if [ -n "$POLL_ZIP" ]; then
    create_or_update_lambda \
        "poll-rss-feeds" \
        "provided.al2" \
        "bootstrap" \
        "$POLL_ZIP" \
        "Variables={MONGODB_URI=mongodb://mongodb:27017/podcast_db,AWS_REGION=us-east-1,AWS_ENDPOINT_URL=http://localstack:4566,S3_BUCKET=podcast-audio,STEP_FUNCTION_ARN=arn:aws:states:us-east-1:000000000000:stateMachine:podcast-transcription}" \
        300 \
        512
fi

# Merge Lambda (Go)
if [ -n "$MERGE_ZIP" ]; then
    create_or_update_lambda \
        "merge-transcript" \
        "provided.al2" \
        "bootstrap" \
        "$MERGE_ZIP" \
        "Variables={MONGODB_URI=mongodb://mongodb:27017/podcast_db,AWS_REGION=us-east-1,S3_BUCKET_TRANSCRIPTS=podcast-transcripts,AWS_ENDPOINT_URL=http://localstack:4566}" \
        300 \
        512
fi

# Chunking Lambda (Python)
if [ -n "$CHUNKING_ZIP" ]; then
    create_or_update_lambda \
        "chunking-lambda" \
        "python3.11" \
        "lambda_handler.lambda_handler" \
        "$CHUNKING_ZIP" \
        "Variables={S3_BUCKET=podcast-audio,AWS_ENDPOINT_URL=http://localstack:4566}" \
        900 \
        1024
fi

# Whisper Lambda (Python)
if [ -n "$WHISPER_ZIP" ]; then
    # Use WHISPER_SERVICE_URL if set, otherwise use OpenAI API
    if [ -n "${WHISPER_SERVICE_URL}" ]; then
        WHISPER_ENV="Variables={WHISPER_SERVICE_URL=${WHISPER_SERVICE_URL},S3_BUCKET=podcast-audio,AWS_ENDPOINT_URL=http://localstack:4566}"
    else
        WHISPER_ENV="Variables={OPENAI_API_KEY=${OPENAI_API_KEY:-your-api-key},S3_BUCKET=podcast-audio,AWS_ENDPOINT_URL=http://localstack:4566}"
    fi

    create_or_update_lambda \
        "whisper-lambda" \
        "python3.11" \
        "handler.lambda_handler" \
        "$WHISPER_ZIP" \
        "$WHISPER_ENV" \
        900 \
        2048
fi

# Create EventBridge rule
echo ""
echo "Creating EventBridge rule for RSS polling..."
awslocal events put-rule \
    --name poll-rss-feeds-schedule \
    --schedule-expression "rate(30 minutes)" \
    --state ENABLED 2>/dev/null || true

awslocal events put-targets \
    --rule poll-rss-feeds-schedule \
    --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:000000000000:function:poll-rss-feeds" 2>/dev/null || true
echo "  EventBridge rule configured"

# Create Step Functions state machine
echo ""
echo "Creating Step Functions state machine..."
STATE_MACHINE_DEF=$(cat <<'EOF'
{
  "Comment": "Podcast episode transcription workflow",
  "StartAt": "DownloadAndChunk",
  "States": {
    "DownloadAndChunk": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:chunking-lambda",
      "Comment": "Download audio file and split into chunks",
      "TimeoutSeconds": 900,
      "ResultPath": "$.chunkingResult",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout", "Lambda.ServiceException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "HandleFailure"
        }
      ],
      "Next": "PrepareForMapping"
    },
    "PrepareForMapping": {
      "Type": "Pass",
      "Comment": "Prepare chunks array and preserve episode_id",
      "Parameters": {
        "episode_id.$": "$.episode_id",
        "chunks.$": "$.chunkingResult.chunks",
        "s3_bucket.$": "$.s3_bucket"
      },
      "Next": "TranscribeChunks"
    },
    "TranscribeChunks": {
      "Type": "Map",
      "ItemsPath": "$.chunks",
      "MaxConcurrency": 10,
      "ResultPath": "$.transcripts",
      "Iterator": {
        "StartAt": "TranscribeChunk",
        "States": {
          "TranscribeChunk": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:us-east-1:000000000000:function:whisper-lambda",
            "TimeoutSeconds": 300,
            "Retry": [
              {
                "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
                "IntervalSeconds": 2,
                "MaxAttempts": 3,
                "BackoffRate": 2.0
              }
            ],
            "Catch": [
              {
                "ErrorEquals": ["States.ALL"],
                "ResultPath": "$.error",
                "Next": "ChunkTranscriptionFailed"
              }
            ],
            "End": true
          },
          "ChunkTranscriptionFailed": {
            "Type": "Fail",
            "Error": "ChunkTranscriptionError",
            "Cause": "Failed to transcribe audio chunk"
          }
        }
      },
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "HandleFailure"
        }
      ],
      "Next": "MergeTranscripts"
    },
    "MergeTranscripts": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:merge-transcript",
      "TimeoutSeconds": 300,
      "InputPath": "$",
      "ResultPath": "$.mergeResult",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed", "States.Timeout"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "HandleFailure"
        }
      ],
      "Next": "ProcessingComplete"
    },
    "ProcessingComplete": {
      "Type": "Pass",
      "Parameters": {
        "episode_id.$": "$.episode_id",
        "status": "completed",
        "final_transcript_key.$": "$.mergeResult.final_transcript_key",
        "message": "Transcription completed successfully"
      },
      "End": true
    },
    "HandleFailure": {
      "Type": "Pass",
      "Parameters": {
        "episode_id.$": "$.episode_id",
        "status": "failed",
        "error_info.$": "$.error",
        "message": "Transcription workflow failed"
      },
      "Next": "WorkflowFailed"
    },
    "WorkflowFailed": {
      "Type": "Fail",
      "Error": "PodcastProcessingError",
      "Cause": "Podcast processing failed"
    }
  }
}
EOF
)

# Delete existing state machine if it exists and recreate
awslocal stepfunctions delete-state-machine \
    --state-machine-arn "arn:aws:states:us-east-1:000000000000:stateMachine:podcast-transcription" 2>/dev/null || true

sleep 1

awslocal stepfunctions create-state-machine \
    --name podcast-transcription \
    --definition "$STATE_MACHINE_DEF" \
    --role-arn "arn:aws:iam::000000000000:role/step-functions-role" \
    > /dev/null

echo "  Step Functions state machine created"

# Print summary
echo ""
echo "============================================"
echo "LocalStack initialization complete!"
echo "============================================"
echo ""
echo "S3 Buckets:"
echo "  - podcast-audio"
echo "  - podcast-transcripts"
echo ""
echo "Lambda Functions:"
awslocal lambda list-functions --query 'Functions[].FunctionName' --output table 2>/dev/null || echo "  (none)"
echo ""
echo "Step Functions:"
echo "  - podcast-transcription"
echo ""
echo "EventBridge:"
echo "  - poll-rss-feeds-schedule (rate: 30 minutes)"
echo ""
echo "To manually invoke Lambdas:"
echo "  awslocal lambda invoke --function-name <name> output.json"
echo "============================================"
