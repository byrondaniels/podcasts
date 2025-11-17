# Whisper Audio Transcription Lambda

AWS Lambda function that transcribes audio chunks using OpenAI Whisper API. Designed to work with AWS Step Functions Map state for parallel processing of podcast episode chunks.

## Features

- Transcribes audio files using OpenAI Whisper API (whisper-1 model)
- Returns detailed JSON with timestamps and segments
- Automatic retry with exponential backoff for rate limits
- S3 integration for audio chunk downloads and transcript uploads
- Comprehensive error handling and logging
- Automatic /tmp cleanup after processing
- CloudWatch monitoring and alarms
- Configurable concurrency for parallel processing

## Architecture

```
┌─────────────────┐
│ Step Functions  │
│   Map State     │
└────────┬────────┘
         │
         ├──────────┬──────────┬──────────┐
         │          │          │          │
         ▼          ▼          ▼          ▼
    ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
    │Lambda 1│ │Lambda 2│ │Lambda 3│ │Lambda N│
    │(chunk)│  │(chunk)│  │(chunk)│  │(chunk)│
    └────┬───┘ └────┬───┘ └────┬───┘ └────┬───┘
         │          │          │          │
         ▼          ▼          ▼          ▼
    ┌──────────────────────────────────────┐
    │              S3 Bucket                │
    │  transcripts/{episode_id}/chunk_*.json│
    └──────────────────────────────────────┘
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Python 3.11
- OpenAI API Key
- S3 bucket for audio chunks and transcripts

## Project Structure

```
whisper-lambda/
├── lambda/
│   ├── handler.py          # Lambda function code
│   └── requirements.txt    # Python dependencies
├── main.tf                 # Terraform main configuration
├── variables.tf            # Terraform input variables
├── outputs.tf              # Terraform outputs
└── README.md              # This file
```

## Installation

### 1. Install Python Dependencies Locally (for testing)

```bash
cd whisper-lambda/lambda
pip install -r requirements.txt
```

### 2. Configure Terraform Variables

Create a `terraform.tfvars` file:

```hcl
# Required variables
openai_api_key = "sk-your-openai-api-key-here"
s3_bucket      = "your-podcast-audio-bucket"

# Optional variables
aws_region          = "us-east-1"
environment         = "production"
function_name       = "whisper-audio-transcription"
lambda_timeout      = 300
lambda_memory_size  = 512
lambda_concurrency  = 10
log_retention_days  = 30
enable_monitoring   = true
```

**Note:** For production, use AWS Secrets Manager or Parameter Store instead of hardcoding the API key:

```hcl
# Use AWS Secrets Manager
data "aws_secretsmanager_secret_version" "openai_key" {
  secret_id = "openai-api-key"
}

# In main.tf, update the Lambda environment variable:
environment {
  variables = {
    OPENAI_API_KEY = data.aws_secretsmanager_secret_version.openai_key.secret_string
    S3_BUCKET      = var.s3_bucket
  }
}
```

### 3. Deploy with Terraform

```bash
cd whisper-lambda

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the changes
terraform apply
```

## Input Format

The Lambda function expects the following input (typically from Step Functions Map state):

```json
{
  "episode_id": "ep123",
  "chunk_index": 0,
  "s3_key": "chunks/ep123/chunk_0.mp3",
  "start_time_seconds": 0,
  "s3_bucket": "podcast-audio-bucket"
}
```

### Input Parameters

- `episode_id` (required): Unique identifier for the episode
- `chunk_index` (required): Index of the audio chunk (0-based)
- `s3_key` (required): S3 key path to the audio chunk file
- `start_time_seconds` (required): Start time of chunk in the full episode
- `s3_bucket` (optional): S3 bucket name (uses env var if not provided)

## Output Format

Success response:

```json
{
  "episode_id": "ep123",
  "chunk_index": 0,
  "transcript_s3_key": "transcripts/ep123/chunk_0.json",
  "start_time_seconds": 0,
  "text_preview": "Welcome to this podcast episode where we discuss...",
  "status": "success"
}
```

Error response:

```json
{
  "episode_id": "ep123",
  "chunk_index": 0,
  "transcript_s3_key": null,
  "start_time_seconds": 0,
  "status": "error",
  "error_message": "Failed to download from S3: Access Denied"
}
```

## Transcript File Format

The transcript JSON file saved to S3 contains:

```json
{
  "episode_id": "ep123",
  "chunk_index": 0,
  "start_time_seconds": 0,
  "text": "Full transcription text...",
  "transcript": {
    "task": "transcribe",
    "language": "en",
    "duration": 120.5
  },
  "segments": [
    {
      "id": 0,
      "start": 0.0,
      "end": 5.5,
      "text": "Welcome to this podcast episode"
    }
  ]
}
```

## Testing

### Test Locally (Mock Event)

```python
import json
from lambda.handler import lambda_handler

event = {
    "episode_id": "test-episode",
    "chunk_index": 0,
    "s3_key": "chunks/test-episode/chunk_0.mp3",
    "start_time_seconds": 0,
    "s3_bucket": "your-bucket-name"
}

# Set environment variables first
import os
os.environ['OPENAI_API_KEY'] = 'your-api-key'
os.environ['S3_BUCKET'] = 'your-bucket-name'

result = lambda_handler(event, None)
print(json.dumps(result, indent=2))
```

### Test via AWS CLI

```bash
aws lambda invoke \
  --function-name whisper-audio-transcription \
  --payload '{"episode_id": "ep123", "chunk_index": 0, "s3_key": "chunks/ep123/chunk_0.mp3", "start_time_seconds": 0}' \
  response.json

cat response.json
```

### Integration with Step Functions

Example Step Functions definition using Map state:

```json
{
  "Comment": "Parallel audio transcription",
  "StartAt": "TranscribeChunks",
  "States": {
    "TranscribeChunks": {
      "Type": "Map",
      "ItemsPath": "$.chunks",
      "MaxConcurrency": 10,
      "Iterator": {
        "StartAt": "TranscribeChunk",
        "States": {
          "TranscribeChunk": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:us-east-1:123456789012:function:whisper-audio-transcription",
            "End": true,
            "Retry": [
              {
                "ErrorEquals": ["States.ALL"],
                "IntervalSeconds": 2,
                "MaxAttempts": 3,
                "BackoffRate": 2.0
              }
            ]
          }
        }
      },
      "End": true
    }
  }
}
```

## Monitoring

### CloudWatch Logs

View logs:

```bash
aws logs tail /aws/lambda/whisper-audio-transcription --follow
```

### CloudWatch Metrics

The following alarms are automatically created (if `enable_monitoring = true`):

1. **Error Alarm**: Triggers if more than 5 errors occur in 5 minutes
2. **Throttle Alarm**: Triggers if more than 2 throttles occur in 5 minutes

### Key Metrics to Monitor

- Invocations
- Errors
- Duration
- Throttles
- Concurrent Executions
- Cost (OpenAI API usage)

## Configuration

### Lambda Settings

- **Runtime**: Python 3.11
- **Memory**: 512 MB (configurable)
- **Timeout**: 5 minutes (300 seconds)
- **Concurrency**: 10 reserved concurrent executions
- **Ephemeral Storage**: 1024 MB (/tmp)

### Retry Strategy

The function implements exponential backoff retry for:
- Rate limit errors (429)
- Timeout errors (503)
- Other transient failures

Retry configuration:
- Initial delay: 1 second
- Max retries: 3
- Backoff multiplier: 2x

## Cost Considerations

### Lambda Costs

- Compute: ~$0.0000166667 per GB-second
- Requests: $0.20 per 1M requests

Example: 100 chunks × 512MB × 60s = ~$0.05

### OpenAI Whisper API Costs

- Whisper-1: $0.006 per minute of audio
- Example: 60 minutes of audio = $0.36

### S3 Costs

- Storage: ~$0.023 per GB/month
- Requests: Minimal cost for PUT/GET operations

## Security Best Practices

1. **API Key Management**
   - Use AWS Secrets Manager or Parameter Store
   - Rotate keys regularly
   - Never commit keys to version control

2. **IAM Permissions**
   - Follows principle of least privilege
   - Separate roles for different environments
   - Scoped to specific S3 bucket

3. **Network Security**
   - Deploy in VPC for additional isolation
   - Use VPC endpoints for S3 access

4. **Monitoring**
   - Enable CloudWatch alarms
   - Monitor for unusual API usage
   - Track failed invocations

## Troubleshooting

### Common Issues

1. **"Access Denied" S3 Error**
   - Check IAM role permissions
   - Verify S3 bucket name in environment variables
   - Ensure bucket exists and is accessible

2. **OpenAI API Rate Limits**
   - Reduce Lambda concurrency
   - Implement additional retry logic
   - Consider upgrading OpenAI plan

3. **Lambda Timeout**
   - Increase timeout setting
   - Check audio file size (should be < 25MB)
   - Monitor OpenAI API response times

4. **Out of Memory**
   - Increase Lambda memory allocation
   - Check audio file sizes
   - Ensure /tmp cleanup is working

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## License

MIT License

## Support

For issues and questions, please open an issue in the repository.

## Future Enhancements

- [ ] Support for multiple audio formats (WAV, M4A, etc.)
- [ ] Batch processing optimization
- [ ] Custom vocabulary support
- [ ] Multi-language detection
- [ ] Cost optimization with Lambda layers
- [ ] Dead letter queue for failed transcriptions
- [ ] SNS notifications for completion/errors
