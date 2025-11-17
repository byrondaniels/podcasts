#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Podcast Chunking Lambda Deployment ===${NC}\n"

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and fill in your values"
    exit 1
fi

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(grep 'aws_region' terraform.tfvars | cut -d '"' -f 2 || echo "us-east-1")

echo -e "${GREEN}✓${NC} AWS Account ID: ${AWS_ACCOUNT_ID}"
echo -e "${GREEN}✓${NC} AWS Region: ${AWS_REGION}"
echo ""

# Initialize Terraform
echo "Initializing Terraform..."
terraform init
echo -e "${GREEN}✓${NC} Terraform initialized\n"

# Create ECR repository if it doesn't exist
echo "Creating ECR repository..."
terraform apply -target=aws_ecr_repository.podcast_chunking_lambda -auto-approve
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/podcast-chunking-lambda"
echo -e "${GREEN}✓${NC} ECR repository ready: ${ECR_REPO}\n"

# Authenticate Docker to ECR
echo "Authenticating Docker to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REPO}
echo -e "${GREEN}✓${NC} Docker authenticated\n"

# Build Docker image
echo "Building Docker image..."
docker build -t podcast-chunking-lambda .
echo -e "${GREEN}✓${NC} Docker image built\n"

# Tag and push image
echo "Pushing image to ECR..."
docker tag podcast-chunking-lambda:latest ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest
echo -e "${GREEN}✓${NC} Image pushed to ECR\n"

# Update terraform.tfvars with image URI if not already set
IMAGE_URI="${ECR_REPO}:latest"
if ! grep -q "lambda_image_uri" terraform.tfvars; then
    echo "lambda_image_uri = \"${IMAGE_URI}\"" >> terraform.tfvars
    echo -e "${YELLOW}Added lambda_image_uri to terraform.tfvars${NC}\n"
fi

# Deploy Lambda function
echo "Deploying Lambda function..."
terraform apply -auto-approve
echo -e "${GREEN}✓${NC} Lambda function deployed\n"

# Get outputs
FUNCTION_NAME=$(terraform output -raw lambda_function_name)
FUNCTION_ARN=$(terraform output -raw lambda_function_arn)
LOG_GROUP=$(terraform output -raw cloudwatch_log_group_name)

echo -e "${GREEN}=== Deployment Complete ===${NC}\n"
echo "Lambda Function Name: ${FUNCTION_NAME}"
echo "Lambda Function ARN: ${FUNCTION_ARN}"
echo "CloudWatch Logs: ${LOG_GROUP}"
echo ""
echo "To test the Lambda function:"
echo "  aws lambda invoke \\"
echo "    --function-name ${FUNCTION_NAME} \\"
echo "    --payload file://test-event.json \\"
echo "    --cli-binary-format raw-in-base64-out \\"
echo "    response.json"
echo ""
echo "To view logs:"
echo "  aws logs tail ${LOG_GROUP} --follow"
