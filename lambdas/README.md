# Lambda Build System

This directory contains the unified Lambda build infrastructure for all Lambda functions.

## Quick Start

```bash
# Build all lambdas
make build-lambdas

# Or use the build script directly
./lambdas/build.sh all
```

## Build Commands

| Command | Description |
|---------|-------------|
| `./lambdas/build.sh all` | Build all Lambda functions |
| `./lambdas/build.sh go` | Build Go Lambdas (poll + merge) |
| `./lambdas/build.sh python` | Build Python Lambdas (chunking + whisper) |
| `./lambdas/build.sh poll` | Build poll-rss-feeds Lambda only |
| `./lambdas/build.sh merge` | Build merge-transcript Lambda only |
| `./lambdas/build.sh chunking` | Build chunking Lambda only |
| `./lambdas/build.sh whisper` | Build whisper Lambda only |
| `./lambdas/build.sh layers` | Build Lambda layers only |
| `./lambdas/build.sh clean` | Remove all build artifacts |

## Architecture

### Dockerfiles

- **Dockerfile.go** - Multi-stage build for Go Lambdas
  - Compiles Go code with `CGO_ENABLED=0` for static binaries
  - Creates minimal zip packages for AWS Lambda
  - Supports both zip and ECR image deployment

- **Dockerfile.python** - Multi-stage build for Python Lambdas
  - Builds shared Python dependencies layer
  - Bundles ffmpeg for audio processing
  - Creates complete deployment packages

### Lambda Functions

| Lambda | Language | Purpose |
|--------|----------|---------|
| poll-rss-feeds | Go | Polls RSS feeds for new episodes |
| merge-transcript | Go | Merges transcript chunks |
| chunking-lambda | Python | Downloads and chunks audio files |
| whisper-lambda | Python | Transcribes audio using Whisper |

### Build Output

After building, zip files are placed in their respective directories:

```
poll-lambda-go/poll-lambda-go.zip
merge-transcript-lambda-go/merge-transcript-lambda-go.zip
chunking-lambda/chunking-lambda.zip
whisper-lambda/whisper-lambda.zip
```

### Lambda Layers

The build system creates reusable Lambda layers:

- **python-deps-layer.zip** - Shared Python dependencies (boto3, pymongo, requests)
- **ffmpeg-layer.zip** - FFmpeg binary for audio processing

## LocalStack Deployment

After building, deploy to LocalStack:

```bash
make deploy-lambdas
```

This runs the init script that creates/updates Lambda functions in LocalStack.

## AWS Deployment

For AWS deployment, use Terraform:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

The unified Terraform module (`terraform/modules/lambda-unified`) handles both Go and Python Lambdas with support for:
- Zip file deployment
- Docker/ECR image deployment
- Lambda layers
- EventBridge scheduling
