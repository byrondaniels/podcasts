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
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Archive Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}"
  output_path = "${path.module}/lambda_function.zip"
  excludes = [
    "lambda_function.zip",
    ".terraform",
    ".terraform.lock.hcl",
    "*.tf",
    "*.tfvars",
    "*.tfstate",
    "*.tfstate.backup",
    ".git"
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "rss_poller" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.lambda_function_name}-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_function_name}-role"

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
    Name        = "${var.lambda_function_name}-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM Policy for Lambda - CloudWatch Logs
resource "aws_iam_role_policy" "lambda_logs" {
  name = "${var.lambda_function_name}-logs-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.rss_poller.arn}:*"
        ]
      }
    ]
  })
}

# IAM Policy for Lambda - Step Functions
resource "aws_iam_role_policy" "lambda_step_functions" {
  name = "${var.lambda_function_name}-stepfunctions-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeExecution"
        ]
        Resource = [
          var.step_function_arn
        ]
      }
    ]
  })
}

# IAM Policy for Lambda - VPC (if needed for MongoDB)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count      = var.enable_vpc ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Layer for dependencies
resource "aws_lambda_layer_version" "dependencies" {
  count               = var.create_lambda_layer ? 1 : 0
  filename            = var.lambda_layer_zip_path
  layer_name          = "${var.lambda_function_name}-dependencies"
  compatible_runtimes = ["python3.11", "python3.12"]

  description = "Dependencies for RSS feed poller: feedparser, pymongo, python-dateutil"

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda Function
resource "aws_lambda_function" "rss_poller" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = var.python_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  layers = var.create_lambda_layer ? [aws_lambda_layer_version.dependencies[0].arn] : var.lambda_layer_arns

  environment {
    variables = {
      MONGODB_URI        = var.mongodb_uri
      STEP_FUNCTION_ARN  = var.step_function_arn
      AWS_REGION         = var.aws_region
      LOG_LEVEL          = var.log_level
    }
  }

  dynamic "vpc_config" {
    for_each = var.enable_vpc ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.rss_poller,
    aws_iam_role_policy.lambda_logs,
    aws_iam_role_policy.lambda_step_functions
  ]

  tags = {
    Name        = var.lambda_function_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# EventBridge Rule - Trigger every 30 minutes
resource "aws_cloudwatch_event_rule" "rss_poller_schedule" {
  name                = "${var.lambda_function_name}-schedule"
  description         = "Trigger RSS feed poller every 30 minutes"
  schedule_expression = var.schedule_expression

  tags = {
    Name        = "${var.lambda_function_name}-schedule"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# EventBridge Target - Link to Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.rss_poller_schedule.name
  target_id = "RSSPollerLambda"
  arn       = aws_lambda_function.rss_poller.arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rss_poller.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rss_poller_schedule.arn
}

# CloudWatch Alarm - Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.lambda_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Lambda function errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.rss_poller.function_name
  }

  tags = {
    Name        = "${var.lambda_function_name}-errors-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Alarm - Lambda Duration
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.lambda_function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "240000" # 4 minutes (80% of 5 minute timeout)
  alarm_description   = "This metric monitors Lambda function duration"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.rss_poller.function_name
  }

  tags = {
    Name        = "${var.lambda_function_name}-duration-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
