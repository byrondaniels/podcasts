#!/bin/bash
set -e

echo "Initializing LocalStack for Podcast App..."

# Wait for LocalStack to be ready
awslocal s3 ls || true

# Create S3 buckets
echo "Creating S3 buckets..."
awslocal s3 mb s3://podcast-audio || echo "Bucket podcast-audio already exists"
awslocal s3 mb s3://podcast-transcripts || echo "Bucket podcast-transcripts already exists"

# Create Poll Lambda function (Go)
echo "Creating Poll Lambda function..."
if [ -f /tmp/lambda/poll-lambda/bootstrap ]; then
    cd /tmp/lambda/poll-lambda
    zip -q function.zip bootstrap

    awslocal lambda create-function \
        --function-name poll-rss-feeds \
        --runtime provided.al2 \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler bootstrap \
        --zip-file fileb://function.zip \
        --timeout 300 \
        --memory-size 512 \
        --environment "Variables={MONGODB_URI=mongodb://mongodb:27017/podcast_db,AWS_REGION=us-east-1,AWS_ENDPOINT_URL=http://localstack:4566,S3_BUCKET=podcast-audio,STEP_FUNCTION_ARN=arn:aws:states:us-east-1:000000000000:stateMachine:podcast-transcription}" \
        || echo "Poll Lambda already exists"
else
    echo "⚠️  Warning: Poll Lambda bootstrap not found. Run 'make build-poll-lambda-go' first."
fi

# Create Merge Lambda function (Go)
echo "Creating Merge Transcript Lambda function..."
if [ -f /tmp/lambda/merge-lambda/bootstrap ]; then
    cd /tmp/lambda/merge-lambda
    zip -q function.zip bootstrap

    awslocal lambda create-function \
        --function-name merge-transcript \
        --runtime provided.al2 \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler bootstrap \
        --zip-file fileb://function.zip \
        --timeout 300 \
        --memory-size 512 \
        --environment "Variables={MONGODB_URI=mongodb://mongodb:27017/podcast_db,AWS_REGION=us-east-1,S3_BUCKET_TRANSCRIPTS=podcast-transcripts}" \
        || echo "Merge Lambda already exists"
else
    echo "⚠️  Warning: Merge Lambda bootstrap not found. Run 'make build-merge-lambda-go' first."
fi

# Create Chunking Lambda function (Python)
echo "Creating Chunking Lambda function..."
if [ -f /tmp/lambda/chunking-lambda.zip ]; then
    awslocal lambda create-function \
        --function-name chunking-lambda \
        --runtime python3.11 \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler lambda_handler.lambda_handler \
        --zip-file fileb:///tmp/lambda/chunking-lambda.zip \
        --timeout 900 \
        --memory-size 1024 \
        --environment "Variables={S3_BUCKET=podcast-audio}" \
        || echo "Chunking Lambda already exists"
else
    echo "⚠️  Warning: Chunking Lambda not found. Run 'make build-chunking-lambda' first."
fi

# Create Whisper Lambda function (Python)
echo "Creating Whisper Lambda function..."
if [ -f /tmp/lambda/whisper-lambda.zip ]; then
    # Use WHISPER_SERVICE_URL if set, otherwise use OpenAI API
    if [ -n "${WHISPER_SERVICE_URL}" ]; then
        WHISPER_ENV="Variables={WHISPER_SERVICE_URL=${WHISPER_SERVICE_URL},S3_BUCKET=podcast-audio,AWS_ENDPOINT_URL=http://localstack:4566}"
    else
        WHISPER_ENV="Variables={OPENAI_API_KEY=${OPENAI_API_KEY:-your-api-key},S3_BUCKET=podcast-audio,AWS_ENDPOINT_URL=http://localstack:4566}"
    fi

    awslocal lambda create-function \
        --function-name whisper-lambda \
        --runtime python3.11 \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler handler.lambda_handler \
        --zip-file fileb:///tmp/lambda/whisper-lambda.zip \
        --timeout 900 \
        --memory-size 2048 \
        --environment "$WHISPER_ENV" \
        || echo "Whisper Lambda already exists"
else
    echo "⚠️  Warning: Whisper Lambda not found. Run 'make build-whisper-lambda' first."
fi

# Create EventBridge rule to trigger Lambda every 30 minutes
echo "Creating EventBridge rule for polling..."
awslocal events put-rule \
    --name poll-rss-feeds-schedule \
    --schedule-expression "rate(30 minutes)" \
    --state ENABLED || echo "EventBridge rule already exists"

awslocal events put-targets \
    --rule poll-rss-feeds-schedule \
    --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:000000000000:function:poll-rss-feeds" || true

# Create Step Functions state machine
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
          "ErrorEquals": [
            "States.TaskFailed",
            "States.Timeout",
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
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
            "Comment": "Transcribe individual audio chunk using Whisper API",
            "TimeoutSeconds": 300,
            "Retry": [
              {
                "ErrorEquals": [
                  "States.TaskFailed",
                  "States.Timeout",
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException"
                ],
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
            "Cause": "Failed to transcribe individual audio chunk after retries"
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
      "Comment": "Combine all transcript chunks into final transcript",
      "TimeoutSeconds": 300,
      "InputPath": "$",
      "ResultPath": "$.mergeResult",
      "Retry": [
        {
          "ErrorEquals": [
            "States.TaskFailed",
            "States.Timeout",
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
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
      "Comment": "Podcast episode processing completed successfully",
      "Parameters": {
        "episode_id.$": "$.episode_id",
        "status": "completed",
        "final_transcript_key.$": "$.mergeResult.final_transcript_key",
        "message": "Transcription workflow completed successfully"
      },
      "End": true
    },
    "HandleFailure": {
      "Type": "Pass",
      "Comment": "Mark episode as failed and prepare error response",
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
      "Cause": "Podcast episode processing failed. Episode marked as failed in database."
    }
  }
}
EOF
)

awslocal stepfunctions create-state-machine \
    --name podcast-transcription \
    --definition "$STATE_MACHINE_DEF" \
    --role-arn arn:aws:iam::000000000000:role/step-functions-role || echo "State machine already exists"

echo "✓ LocalStack initialization complete!"
echo ""
echo "Available services:"
echo "  - S3 buckets: podcast-audio, podcast-transcripts"
echo "  - Lambdas:"
echo "    • poll-rss-feeds (triggered every 30 minutes)"
echo "    • chunking-lambda"
echo "    • whisper-lambda"
echo "    • merge-transcript"
echo "  - Step Functions: podcast-transcription"
echo ""
echo "To manually invoke Lambdas:"
echo "  awslocal lambda invoke --function-name poll-rss-feeds output.json"
echo "  awslocal lambda list-functions"
