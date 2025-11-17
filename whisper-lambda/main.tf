terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "podcast-transcription"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for AWS region
data "aws_region" "current" {}

# IAM Role for Lambda Function
resource "aws_iam_role" "whisper_lambda_role" {
  name               = "${var.function_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.function_name}-role"
  }
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "s3_access_policy" {
  name        = "${var.function_name}-s3-access"
  description = "Allow Lambda to read/write from S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}"
        ]
      }
    ]
  })
}

# Attach S3 policy to Lambda role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.whisper_lambda_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.whisper_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.function_name}-logs"
  }
}

# Create deployment package
data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_package.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

# Lambda Function
resource "aws_lambda_function" "whisper_transcription" {
  filename         = data.archive_file.lambda_package.output_path
  function_name    = var.function_name
  role            = aws_iam_role.whisper_lambda_role.arn
  handler         = "handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  runtime         = "python3.11"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      OPENAI_API_KEY = var.openai_api_key
      S3_BUCKET      = var.s3_bucket
      LOG_LEVEL      = var.log_level
    }
  }

  reserved_concurrent_executions = var.lambda_concurrency

  ephemeral_storage {
    size = 1024  # 1GB /tmp storage for audio files
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.s3_access_attachment
  ]

  tags = {
    Name = var.function_name
  }
}

# Lambda Function URL (optional - for testing)
resource "aws_lambda_function_url" "whisper_url" {
  count              = var.enable_function_url ? 1 : 0
  function_name      = aws_lambda_function.whisper_transcription.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["*"]
    max_age          = 86400
  }
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "Errors"
  namespace          = "AWS/Lambda"
  period             = "300"
  statistic          = "Sum"
  threshold          = "5"
  alarm_description  = "This metric monitors lambda errors"
  treat_missing_data = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.whisper_transcription.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "Throttles"
  namespace          = "AWS/Lambda"
  period             = "300"
  statistic          = "Sum"
  threshold          = "2"
  alarm_description  = "This metric monitors lambda throttles"
  treat_missing_data = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.whisper_transcription.function_name
  }
}

# Lambda Layer for dependencies (optional - for faster deployments)
# Note: You need to build this layer separately with dependencies
# resource "aws_lambda_layer_version" "dependencies" {
#   filename            = "lambda_layer.zip"
#   layer_name          = "${var.function_name}-dependencies"
#   compatible_runtimes = ["python3.11"]
#   source_code_hash    = filebase64sha256("lambda_layer.zip")
# }
