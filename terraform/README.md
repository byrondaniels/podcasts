# Podcast Transcription Infrastructure - Terraform

This directory contains Terraform configuration for deploying the complete podcast transcription infrastructure on AWS.

## Architecture Overview

The infrastructure consists of:

- **S3 Buckets**: Storage for audio files, chunks, and transcripts with lifecycle policies
- **Lambda Functions**: 4 serverless functions for RSS polling, audio chunking, transcription, and merging
- **Step Functions**: State machine orchestrating the podcast processing workflow
- **EventBridge**: Scheduled trigger for RSS feed polling (every 30 minutes)
- **SSM Parameter Store**: Secure storage for MongoDB URI and OpenAI API key
- **CloudWatch**: Log groups with 7-day retention for all services
- **IAM**: Roles and policies with least-privilege permissions

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed ([Download](https://www.terraform.io/downloads))
3. **AWS CLI** configured with credentials ([Setup Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
4. **MongoDB** database (Atlas or self-hosted)
5. **OpenAI API Key** for Whisper transcription

## Directory Structure

```
terraform/
├── main.tf                      # Root module configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── terraform.tfvars.example     # Example variable values
├── README.md                    # This file
└── modules/
    ├── s3/                      # S3 buckets with lifecycle rules
    ├── lambda/                  # Reusable Lambda module
    ├── step-functions/          # State machine definition
    └── ssm/                     # SSM Parameter Store
```

## Quick Start

### 1. Clone and Navigate

```bash
cd terraform
```

### 2. Configure Variables

Create a `terraform.tfvars` file with your configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# AWS Configuration
aws_region  = "us-east-1"
environment = "dev"

# Project Configuration
project_name = "podcast"

# Secrets
mongodb_uri    = "mongodb+srv://user:password@cluster.mongodb.net/podcast_db"
openai_api_key = "sk-..."

# Optional
log_level = "INFO"
```

**IMPORTANT**: Add `terraform.tfvars` to `.gitignore` to prevent committing secrets!

### 3. Initialize Terraform

```bash
terraform init
```

This downloads the required provider plugins (AWS, Archive).

### 4. Review the Plan

```bash
terraform plan
```

Review the resources that will be created. Expected resources:
- 2 S3 buckets
- 4 Lambda functions
- 1 Step Functions state machine
- 1 EventBridge rule
- 2 SSM parameters
- 7+ CloudWatch log groups
- IAM roles and policies

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm deployment.

Deployment typically takes 2-3 minutes.

### 6. View Outputs

After successful deployment, Terraform will display important outputs:

```bash
terraform output
```

Example output:
```
s3_audio_bucket_name = "podcast-audio-dev"
s3_transcript_bucket_name = "podcast-transcripts-dev"
step_function_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:podcast-processing-workflow"
lambda_rss_poller_arn = "arn:aws:lambda:us-east-1:123456789012:function:rss-feed-poller"
...
```

## Infrastructure Details

### S3 Buckets

1. **Audio Bucket** (`podcast-audio-{env}`)
   - Stores raw audio files and chunks
   - Lifecycle policy: Deletes files under `chunks/` prefix after 7 days
   - Server-side encryption enabled (AES256)
   - Public access blocked

2. **Transcript Bucket** (`podcast-transcripts-{env}`)
   - Stores final transcripts
   - Versioning enabled
   - Server-side encryption enabled (AES256)
   - Public access blocked

### Lambda Functions

| Function | Runtime | Memory | Timeout | Concurrency | Purpose |
|----------|---------|--------|---------|-------------|---------|
| `rss-feed-poller` | Python 3.11 | 512 MB | 5 min | Default | Polls RSS feeds, triggers workflow |
| `podcast-audio-chunking` | Python 3.11 | 3 GB | 10 min | Default | Splits audio into 10-min chunks |
| `whisper-audio-transcription` | Python 3.11 | 512 MB | 5 min | 10 | Transcribes chunks via Whisper API |
| `merge-transcript-chunks` | Python 3.11 | 512 MB | 2 min | 5 | Combines chunks into final transcript |

All functions:
- Use SSM Parameter Store for secrets (not environment variables)
- Have CloudWatch Logs with 7-day retention
- Include error retry logic
- Use least-privilege IAM roles

### Step Functions Workflow

```
ChunkAudio (Task)
    ↓
TranscribeChunks (Map, max concurrency: 10)
    ↓
MergeTranscripts (Task)
```

- **Error Handling**: Automatic retries with exponential backoff
- **Logging**: Execution logs in CloudWatch (ERROR level)
- **Parallel Processing**: Up to 10 concurrent transcriptions

### EventBridge Schedule

- **Rule**: Triggers `rss-feed-poller` every 30 minutes
- **Expression**: `rate(30 minutes)`
- **Target**: RSS Poller Lambda function

### SSM Parameters (SecureString)

- `/podcast-app/mongodb-uri`: MongoDB connection string
- `/podcast-app/openai-api-key`: OpenAI API key

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region | `us-east-1` | No |
| `environment` | Environment (dev/staging/prod) | `dev` | No |
| `project_name` | Project name prefix | `podcast` | No |
| `mongodb_uri` | MongoDB connection URI | - | **Yes** |
| `openai_api_key` | OpenAI API key | - | **Yes** |
| `log_level` | Lambda log level | `INFO` | No |
| `tags` | Additional resource tags | `{}` | No |

## Managing Infrastructure

### Update Resources

After modifying Terraform files:

```bash
terraform plan   # Review changes
terraform apply  # Apply changes
```

### Destroy Infrastructure

**WARNING**: This deletes ALL resources including S3 buckets and data!

```bash
terraform destroy
```

### View Current State

```bash
terraform show
terraform state list
```

### Update Secrets

To update SSM parameters:

1. Edit `terraform.tfvars`
2. Run `terraform apply`

Terraform will update the parameter values.

## Environment-Specific Deployments

To deploy multiple environments (dev, staging, prod):

### Option 1: Terraform Workspaces

```bash
# Create and switch to prod workspace
terraform workspace new prod
terraform workspace select prod

# Deploy with prod variables
terraform apply -var-file="prod.tfvars"
```

### Option 2: Separate State Files

```bash
# Use different state files per environment
terraform apply -var="environment=prod" -state="prod.tfstate"
```

### Option 3: Separate Directories

```
terraform/
├── dev/
│   └── main.tf (calls modules)
├── staging/
│   └── main.tf (calls modules)
└── prod/
    └── main.tf (calls modules)
```

## Troubleshooting

### Issue: Lambda Functions Not Updating

**Solution**: Terraform only updates when code changes. To force update:

```bash
terraform taint module.lambda_rss_poller.aws_lambda_function.function
terraform apply
```

### Issue: SSM Parameters Not Accessible

**Check**:
1. IAM roles have `ssm:GetParameter` permission
2. Lambda code reads from SSM using correct parameter names
3. Parameters exist in the correct region

```bash
aws ssm get-parameter --name /podcast-app/mongodb-uri --region us-east-1
```

### Issue: S3 Bucket Already Exists

**Solution**: S3 bucket names must be globally unique. Change `project_name` or add a random suffix.

### Issue: Step Functions Execution Failing

**Debug**:
1. View execution history in AWS Console
2. Check CloudWatch Logs: `/aws/states/podcast-processing-workflow`
3. Test individual Lambda functions

```bash
aws stepfunctions describe-execution --execution-arn <arn>
```

## Cost Estimation

Approximate monthly costs (us-east-1, dev environment):

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 1000 executions, 5 min avg | ~$0.50 |
| S3 | 100 GB storage, 10k requests | ~$2.30 |
| Step Functions | 100 executions | ~$0.03 |
| CloudWatch Logs | 5 GB ingestion | ~$2.50 |
| SSM Parameters | 2 parameters | Free |
| **Total** | | **~$5.33/month** |

**Note**: Whisper API costs are separate and depend on audio duration.

## Security Best Practices

1. **Never commit `terraform.tfvars`** to git
2. **Use least-privilege IAM policies** (already configured)
3. **Enable MFA** on AWS accounts
4. **Rotate secrets** regularly via SSM Parameter Store
5. **Review CloudTrail logs** for audit trail
6. **Enable S3 bucket versioning** for production
7. **Use VPC** for MongoDB if self-hosted (set `enable_vpc = true`)

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths: ['terraform/**']

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform

      - name: Terraform Plan
        run: terraform plan
        working-directory: ./terraform
        env:
          TF_VAR_mongodb_uri: ${{ secrets.MONGODB_URI }}
          TF_VAR_openai_api_key: ${{ secrets.OPENAI_API_KEY }}

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
        working-directory: ./terraform
        env:
          TF_VAR_mongodb_uri: ${{ secrets.MONGODB_URI }}
          TF_VAR_openai_api_key: ${{ secrets.OPENAI_API_KEY }}
```

## Module Documentation

### Lambda Module

Creates a Lambda function with CloudWatch Logs, IAM role, and optional EventBridge trigger.

**Usage:**
```hcl
module "my_lambda" {
  source = "./modules/lambda"

  function_name = "my-function"
  handler       = "index.handler"
  runtime       = "python3.11"
  source_dir    = "./lambda-code"

  environment_variables = {
    KEY = "value"
  }

  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::bucket/*"]
    }
  ]
}
```

### S3 Module

Creates S3 buckets with encryption, lifecycle policies, and public access block.

### Step Functions Module

Creates a state machine with IAM role and CloudWatch Logs.

### SSM Module

Creates SecureString parameters in Parameter Store.

## Additional Resources

- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [S3 Lifecycle Configuration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)

## Support

For issues or questions:
1. Check CloudWatch Logs for errors
2. Review Terraform plan output
3. Consult AWS documentation
4. Open an issue in the repository

## License

MIT
