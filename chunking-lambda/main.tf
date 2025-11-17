terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ECR Repository for Lambda container image
resource "aws_ecr_repository" "podcast_chunking_lambda" {
  name                 = "podcast-chunking-lambda"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "Podcast Chunking Lambda"
    Environment = var.environment
  }
}

# ECR Lifecycle Policy to keep only recent images
resource "aws_ecr_lifecycle_policy" "podcast_chunking_lambda" {
  repository = aws_ecr_repository.podcast_chunking_lambda.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "podcast_chunking_lambda" {
  name = "podcast-chunking-lambda-role"

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
    Name        = "Podcast Chunking Lambda Role"
    Environment = var.environment
  }
}

# IAM Policy for S3 access
resource "aws_iam_role_policy" "s3_access" {
  name = "s3-access-policy"
  role = aws_iam_role.podcast_chunking_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.podcast_chunking_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "podcast_chunking_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.podcast_chunking.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "Podcast Chunking Lambda Logs"
    Environment = var.environment
  }
}

# Lambda Function
resource "aws_lambda_function" "podcast_chunking" {
  function_name = "podcast-audio-chunking"
  role          = aws_iam_role.podcast_chunking_lambda.arn
  package_type  = "Image"
  image_uri     = var.lambda_image_uri
  timeout       = 600  # 10 minutes
  memory_size   = 3008  # 3GB to handle large audio files

  environment {
    variables = {
      MONGODB_URI     = var.mongodb_uri
      MONGODB_DB_NAME = var.mongodb_db_name
    }
  }

  ephemeral_storage {
    size = 10240  # 10GB for large audio files
  }

  tags = {
    Name        = "Podcast Audio Chunking Lambda"
    Environment = var.environment
  }

  # Prevent deployment until image is pushed
  lifecycle {
    ignore_changes = [image_uri]
  }
}

# CloudWatch Log Stream
resource "aws_cloudwatch_log_stream" "podcast_chunking_lambda" {
  name           = "lambda-stream"
  log_group_name = aws_cloudwatch_log_group.podcast_chunking_lambda.name
}
