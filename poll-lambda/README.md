# RSS Feed Poller Lambda Function

A serverless AWS Lambda function that polls RSS feeds for podcast episodes and queues them for processing using AWS Step Functions.

## Features

- **Automatic RSS Polling**: Scheduled to run every 30 minutes via EventBridge
- **MongoDB Integration**: Queries active podcasts and stores new episodes
- **Step Functions Integration**: Triggers processing workflow for each new episode
- **Idempotency**: Prevents reprocessing of existing episodes
- **Error Handling**: Graceful handling of feed parsing errors and failures
- **Comprehensive Logging**: CloudWatch logs for monitoring and debugging
- **CloudWatch Alarms**: Alerts for errors and long execution times

## Architecture

```
EventBridge (every 30 min) → Lambda Function → MongoDB (query podcasts)
                                     ↓
                              Parse RSS Feeds
                                     ↓
                              Find New Episodes
                                     ↓
                              MongoDB (insert episodes)
                                     ↓
                              Step Functions (trigger processing)
```

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- Python 3.11+
- MongoDB instance (local, Atlas, or DocumentDB)
- Step Functions state machine for episode processing

## Directory Structure

```
poll-lambda/
├── handler.py                 # Lambda function code
├── requirements.txt           # Python dependencies
├── main.tf                    # Terraform main configuration
├── variables.tf               # Terraform variables
├── outputs.tf                 # Terraform outputs
├── terraform.tfvars.example   # Example configuration
├── build_layer.sh            # Script to build Lambda layer
└── README.md                 # This file
```

## Setup Instructions

### 1. Clone and Navigate

```bash
cd poll-lambda
```

### 2. Configure Terraform Variables

Copy the example configuration and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:

- `mongodb_uri`: Your MongoDB connection string
- `step_function_arn`: ARN of your Step Functions state machine
- `aws_region`: Your preferred AWS region

### 3. Build Lambda Layer

Build the Lambda layer with all required dependencies:

```bash
./build_layer.sh
```

This creates `lambda-layer.zip` with all Python dependencies.

### 4. Deploy with Terraform

Initialize Terraform:

```bash
terraform init
```

Review the deployment plan:

```bash
terraform plan
```

Deploy the infrastructure:

```bash
terraform apply
```

## Configuration

### Environment Variables

The Lambda function uses these environment variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `MONGODB_URI` | MongoDB connection string | Yes |
| `STEP_FUNCTION_ARN` | ARN of Step Functions state machine | Yes |
| `AWS_REGION` | AWS region for Step Functions client | Yes |
| `LOG_LEVEL` | Logging level (DEBUG, INFO, WARNING, ERROR) | No (default: INFO) |

### MongoDB Schema

#### Podcasts Collection

```javascript
{
  _id: ObjectId,
  title: String,
  feed_url: String,        // or rss_url
  active: Boolean,
  // ... other fields
}
```

#### Episodes Collection

```javascript
{
  _id: String,             // episode_id (hash of audio_url)
  episode_id: String,
  podcast_id: String,
  title: String,
  description: String,
  audio_url: String,
  published_date: Date,
  status: String,          // 'pending', 'processing', 'completed', 'failed'
  created_at: Date,
  updated_at: Date
}
```

### Terraform Variables

Key configuration variables in `variables.tf`:

| Variable | Description | Default |
|----------|-------------|---------|
| `lambda_function_name` | Name of the Lambda function | `rss-feed-poller` |
| `lambda_timeout` | Function timeout in seconds | `300` (5 min) |
| `lambda_memory_size` | Memory allocation in MB | `512` |
| `schedule_expression` | EventBridge schedule | `rate(30 minutes)` |
| `log_retention_days` | CloudWatch log retention | `14` |

## Usage

### Manual Invocation

Test the function manually:

```bash
aws lambda invoke \
  --function-name rss-feed-poller \
  --payload '{}' \
  response.json
cat response.json
```

### View Logs

```bash
aws logs tail /aws/lambda/rss-feed-poller --follow
```

### Monitor Execution

Check CloudWatch metrics:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=rss-feed-poller \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

## Error Handling

The function implements comprehensive error handling:

1. **Feed Parsing Errors**: Logged and processing continues with other podcasts
2. **MongoDB Errors**: Function returns 500 status with error details
3. **Step Functions Errors**: Episode status set to 'failed' with error message
4. **Duplicate Episodes**: Handled gracefully via MongoDB unique constraints

## Monitoring

### CloudWatch Alarms

Two alarms are automatically created:

1. **Error Alarm**: Triggers when errors > 5 in 5 minutes
2. **Duration Alarm**: Triggers when execution time > 4 minutes (80% of timeout)

### Metrics to Monitor

- **Invocations**: Number of times function is triggered
- **Errors**: Number of failed executions
- **Duration**: Execution time
- **Concurrent Executions**: Number of parallel executions

## Development

### Local Testing

Set up local environment:

```bash
export MONGODB_URI="mongodb://localhost:27017/podcast-db"
export STEP_FUNCTION_ARN="arn:aws:states:us-east-1:123456789012:stateMachine:test"
export AWS_REGION="us-east-1"

python -c "from handler import lambda_handler; print(lambda_handler({}, {}))"
```

### Adding Dependencies

1. Add package to `requirements.txt`
2. Rebuild Lambda layer: `./build_layer.sh`
3. Redeploy: `terraform apply`

## VPC Configuration

If your MongoDB is in a VPC (e.g., AWS DocumentDB):

```hcl
enable_vpc             = true
vpc_subnet_ids         = ["subnet-12345678", "subnet-87654321"]
vpc_security_group_ids = ["sg-12345678"]
```

Note: VPC configuration adds cold start latency.

## Troubleshooting

### Function Times Out

- Increase `lambda_timeout` in `terraform.tfvars`
- Reduce number of podcasts processed per invocation
- Check MongoDB connection latency

### Episodes Not Being Queued

- Verify `STEP_FUNCTION_ARN` is correct
- Check IAM permissions for Step Functions
- Review CloudWatch logs for errors

### Feed Parsing Failures

- Check feed URL is accessible
- Validate RSS feed format
- Review logs for specific parsing errors

## Cost Optimization

- **Memory**: Start with 512MB, adjust based on metrics
- **Timeout**: Monitor actual duration and reduce timeout if possible
- **Schedule**: Adjust polling frequency based on podcast update patterns
- **Log Retention**: Reduce retention days for cost savings

## Security Best Practices

1. **MongoDB URI**: Store in AWS Secrets Manager (not environment variables)
2. **IAM Roles**: Use least privilege permissions
3. **VPC**: Deploy in VPC for private MongoDB access
4. **Encryption**: Enable encryption at rest for CloudWatch logs

## Step Functions Integration

The function triggers a Step Functions workflow with this payload:

```json
{
  "episode_id": "abc123...",
  "audio_url": "https://example.com/episode.mp3",
  "s3_bucket": "podcast-audio-bucket"
}
```

Your Step Functions state machine should:
1. Download audio from `audio_url`
2. Upload to S3 bucket
3. Process/transcode audio
4. Update episode status in MongoDB

## Cleanup

Remove all resources:

```bash
terraform destroy
```

## License

MIT

## Support

For issues or questions, please open an issue in the repository.
