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
        --environment Variables="{
            MONGODB_URI=mongodb://mongodb:27017/podcast_db,
            AWS_REGION=us-east-1,
            S3_BUCKET=podcast-audio,
            STEP_FUNCTION_ARN=arn:aws:states:us-east-1:000000000000:stateMachine:podcast-transcription
        }" || echo "Poll Lambda already exists"
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
        --environment Variables="{
            MONGODB_URI=mongodb://mongodb:27017/podcast_db,
            AWS_REGION=us-east-1,
            S3_BUCKET_TRANSCRIPTS=podcast-transcripts
        }" || echo "Merge Lambda already exists"
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
        --handler lambda_function.lambda_handler \
        --zip-file fileb:///tmp/lambda/chunking-lambda.zip \
        --timeout 900 \
        --memory-size 1024 \
        --environment Variables="{
            S3_BUCKET=podcast-audio
        }" || echo "Chunking Lambda already exists"
else
    echo "⚠️  Warning: Chunking Lambda not found. Run 'make build-chunking-lambda' first."
fi

# Create Whisper Lambda function (Python)
echo "Creating Whisper Lambda function..."
if [ -f /tmp/lambda/whisper-lambda.zip ]; then
    awslocal lambda create-function \
        --function-name whisper-lambda \
        --runtime python3.11 \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler lambda_function.lambda_handler \
        --zip-file fileb:///tmp/lambda/whisper-lambda.zip \
        --timeout 900 \
        --memory-size 2048 \
        --environment Variables="{
            OPENAI_API_KEY=${OPENAI_API_KEY:-your-api-key},
            S3_BUCKET=podcast-audio
        }" || echo "Whisper Lambda already exists"
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
awslocal stepfunctions create-state-machine \
    --name podcast-transcription \
    --definition '{
        "Comment": "Podcast transcription workflow",
        "StartAt": "Placeholder",
        "States": {
            "Placeholder": {
                "Type": "Pass",
                "Result": "Transcription workflow not fully implemented in LocalStack",
                "End": true
            }
        }
    }' \
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
