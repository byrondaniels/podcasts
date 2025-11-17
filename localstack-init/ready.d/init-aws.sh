#!/bin/bash

# LocalStack initialization script
# This script runs when LocalStack is ready and creates necessary AWS resources

echo "Initializing LocalStack AWS resources..."

# Set AWS configuration
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Wait for LocalStack to be fully ready
sleep 5

# Create S3 bucket for podcast audio files
echo "Creating S3 bucket: podcast-audio"
awslocal s3 mb s3://podcast-audio 2>/dev/null || echo "Bucket podcast-audio already exists"

# Create S3 bucket for transcripts
echo "Creating S3 bucket: podcast-transcripts"
awslocal s3 mb s3://podcast-transcripts 2>/dev/null || echo "Bucket podcast-transcripts already exists"

# Enable CORS on podcast-audio bucket
echo "Configuring CORS for podcast-audio bucket"
awslocal s3api put-bucket-cors --bucket podcast-audio --cors-configuration '{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"]
    }
  ]
}'

# Enable CORS on podcast-transcripts bucket
echo "Configuring CORS for podcast-transcripts bucket"
awslocal s3api put-bucket-cors --bucket podcast-transcripts --cors-configuration '{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"]
    }
  ]
}'

# List created buckets
echo "Created S3 buckets:"
awslocal s3 ls

echo "LocalStack initialization complete!"
