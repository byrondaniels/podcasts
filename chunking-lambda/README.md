# Podcast Audio Chunking Lambda

This Lambda function downloads podcast audio files, splits them into 20-minute chunks, and uploads them to S3 for further processing.

## Features

- Downloads audio from any URL
- Splits audio into 20-minute chunks (1,200,000 ms)
- Exports chunks as MP3 with 64kbps bitrate
- Uploads chunks to S3
- Updates MongoDB episode status
- Comprehensive error handling and logging
- Supports large audio files (up to 4 hours)

## Architecture

- **Runtime**: Python 3.11 (Container Image)
- **Dependencies**: boto3, pydub, pymongo, requests
- **System Requirements**: ffmpeg (included in Docker image)
- **Timeout**: 10 minutes
- **Memory**: 3GB
- **Ephemeral Storage**: 10GB

## Input Schema

```json
{
  "episode_id": "ep123",
  "audio_url": "https://example.com/episode.mp3",
  "s3_bucket": "podcast-audio-bucket"
}
```

## Output Schema

```json
{
  "episode_id": "ep123",
  "total_chunks": 12,
  "chunks": [
    {
      "chunk_index": 0,
      "s3_key": "chunks/ep123/chunk_0.mp3",
      "start_time_seconds": 0,
      "end_time_seconds": 1200
    }
  ]
}
```

## Deployment Instructions

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Docker installed and running
3. Terraform >= 1.0
4. MongoDB instance accessible from Lambda

### Step 1: Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Create ECR Repository

```bash
# Apply only the ECR repository first
terraform apply -target=aws_ecr_repository.podcast_chunking_lambda
```

### Step 4: Build and Push Docker Image

```bash
# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"  # Update with your region
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/podcast-chunking-lambda"

# Authenticate Docker to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REPO}

# Build Docker image
docker build -t podcast-chunking-lambda .

# Tag image
docker tag podcast-chunking-lambda:latest ${ECR_REPO}:latest

# Push to ECR
docker push ${ECR_REPO}:latest
```

### Step 5: Update terraform.tfvars

Add the image URI to your `terraform.tfvars`:

```hcl
lambda_image_uri = "123456789012.dkr.ecr.us-east-1.amazonaws.com/podcast-chunking-lambda:latest"
```

### Step 6: Deploy Lambda Function

```bash
terraform apply
```

### Step 7: Test the Lambda

Create a test event `test-event.json`:

```json
{
  "episode_id": "test-ep-001",
  "audio_url": "https://example.com/test-audio.mp3",
  "s3_bucket": "your-podcast-audio-bucket"
}
```

Invoke the Lambda:

```bash
aws lambda invoke \
  --function-name podcast-audio-chunking \
  --payload file://test-event.json \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json
```

## MongoDB Schema

The Lambda expects an `episodes` collection with documents like:

```javascript
{
  episode_id: "ep123",
  status: "pending",  // Will be updated to "processing" or "error"
  s3_audio_key: null,  // Will be set to "audio/{episode_id}.mp3"
  // ... other fields
}
```

## S3 Structure

```
your-bucket/
├── chunks/
│   ├── ep123/
│   │   ├── chunk_0.mp3
│   │   ├── chunk_1.mp3
│   │   └── ...
│   └── ep124/
│       └── ...
└── audio/
    └── (original audio files)
```

## Environment Variables

- `MONGODB_URI`: MongoDB connection string (set via Terraform)
- `MONGODB_DB_NAME`: Database name (default: `podcast_db`)

## Error Handling

- Network errors during download are logged and raised
- Audio loading failures are captured and reported
- S3 upload failures stop processing and report the error
- MongoDB errors are logged and raised
- All errors update the episode status to "error" in MongoDB
- Temporary files are cleaned up even if errors occur

## Monitoring

CloudWatch Logs are available at:
```
/aws/lambda/podcast-audio-chunking
```

Log retention: 14 days (configurable via `log_retention_days` variable)

## Estimated Costs

For a 2-hour podcast:
- Lambda execution: ~2-3 minutes @ 3GB memory ≈ $0.01
- S3 storage: 6 chunks × ~10MB = ~60MB ≈ $0.001/month
- Data transfer: Varies by audio source

## Updating the Lambda

To update the Lambda function code:

```bash
# Make changes to lambda_handler.py
# Rebuild and push Docker image
docker build -t podcast-chunking-lambda .
docker tag podcast-chunking-lambda:latest ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest

# Lambda will automatically use the new image
# Or force update:
aws lambda update-function-code \
  --function-name podcast-audio-chunking \
  --image-uri ${ECR_REPO}:latest
```

## Troubleshooting

### Lambda timeout
- Increase timeout in `main.tf` (max 15 minutes)
- Increase memory (more memory = faster processing)

### Out of disk space
- Increase `ephemeral_storage` in `main.tf` (max 10GB)

### MongoDB connection issues
- Ensure MongoDB allows Lambda's IP range
- Check security group if using VPC
- Verify connection string format

### S3 permission denied
- Verify IAM role has correct S3 permissions
- Check S3 bucket policy

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Note: This will delete the ECR repository and all images.
