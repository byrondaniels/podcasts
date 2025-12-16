# Unified Lambda Module
# Supports both Go and Python Lambdas with zip or Docker image deployment

locals {
  # Determine if this is a Go Lambda (custom runtime) or Python
  is_go_lambda = var.runtime == "provided.al2023" || var.runtime == "provided.al2"

  # Handler for Go is always "bootstrap"
  effective_handler = local.is_go_lambda ? "bootstrap" : var.handler

  # Source code hash for change detection
  source_hash = var.zip_file_path != null ? filebase64sha256(var.zip_file_path) : (
    var.docker_image_uri != null ? var.docker_image_tag : null
  )
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.function_name}-logs"
    Environment = var.environment
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-role"

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
    Name        = "${var.function_name}-role"
    Environment = var.environment
  }
}

# IAM Policy for CloudWatch Logs
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.function_name}-cloudwatch-logs"
  role = aws_iam_role.lambda.id

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
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      }
    ]
  })
}

# IAM Policy for custom permissions
resource "aws_iam_role_policy" "custom" {
  count = length(var.policy_statements) > 0 ? 1 : 0
  name  = "${var.function_name}-custom-policy"
  role  = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.policy_statements
  })
}

# Attach VPC execution policy if needed
resource "aws_iam_role_policy_attachment" "vpc_execution" {
  count      = var.enable_vpc ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Function - Zip deployment
resource "aws_lambda_function" "zip" {
  count = var.zip_file_path != null ? 1 : 0

  filename         = var.zip_file_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda.arn
  handler          = local.effective_handler
  source_code_hash = filebase64sha256(var.zip_file_path)
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size
  architectures    = var.architectures

  reserved_concurrent_executions = var.reserved_concurrent_executions > 0 ? var.reserved_concurrent_executions : null

  environment {
    variables = var.environment_variables
  }

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size > 512 ? [1] : []
    content {
      size = var.ephemeral_storage_size
    }
  }

  dynamic "vpc_config" {
    for_each = var.enable_vpc ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  # Attach layers if specified
  layers = var.layer_arns

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.cloudwatch_logs
  ]

  tags = {
    Name        = var.function_name
    Environment = var.environment
    Runtime     = var.runtime
  }
}

# Lambda Function - Docker image deployment
resource "aws_lambda_function" "docker" {
  count = var.docker_image_uri != null ? 1 : 0

  function_name = var.function_name
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${var.docker_image_uri}:${var.docker_image_tag}"
  timeout       = var.timeout
  memory_size   = var.memory_size
  architectures = var.architectures

  reserved_concurrent_executions = var.reserved_concurrent_executions > 0 ? var.reserved_concurrent_executions : null

  environment {
    variables = var.environment_variables
  }

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size > 512 ? [1] : []
    content {
      size = var.ephemeral_storage_size
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
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.cloudwatch_logs
  ]

  tags = {
    Name        = var.function_name
    Environment = var.environment
    PackageType = "Image"
  }
}

# Local to get the actual Lambda function (whichever was created)
locals {
  lambda_function = var.docker_image_uri != null ? aws_lambda_function.docker[0] : aws_lambda_function.zip[0]
}

# EventBridge Rule (optional)
resource "aws_cloudwatch_event_rule" "schedule" {
  count               = var.create_eventbridge_rule ? 1 : 0
  name                = "${var.function_name}-schedule"
  description         = "Trigger ${var.function_name} on schedule"
  schedule_expression = var.schedule_expression

  tags = {
    Name        = "${var.function_name}-schedule"
    Environment = var.environment
  }
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "lambda" {
  count     = var.create_eventbridge_rule ? 1 : 0
  rule      = aws_cloudwatch_event_rule.schedule[0].name
  target_id = "${var.function_name}-target"
  arn       = local.lambda_function.arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "eventbridge" {
  count         = var.create_eventbridge_rule ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = local.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule[0].arn
}
