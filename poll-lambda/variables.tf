variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "rss-feed-poller"
}

variable "python_runtime" {
  description = "Python runtime version for Lambda"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300 # 5 minutes
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "mongodb_uri" {
  description = "MongoDB connection URI"
  type        = string
  sensitive   = true
}

variable "step_function_arn" {
  description = "ARN of the Step Functions state machine for episode processing"
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge schedule expression for triggering the Lambda"
  type        = string
  default     = "rate(30 minutes)"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}

variable "log_level" {
  description = "Logging level for Lambda function"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL"
  }
}

variable "create_lambda_layer" {
  description = "Whether to create a Lambda layer for dependencies (requires lambda_layer_zip_path)"
  type        = bool
  default     = false
}

variable "lambda_layer_zip_path" {
  description = "Path to the Lambda layer zip file containing dependencies"
  type        = string
  default     = ""
}

variable "lambda_layer_arns" {
  description = "List of Lambda layer ARNs to attach (if not creating layer)"
  type        = list(string)
  default     = []
}

variable "enable_vpc" {
  description = "Whether to deploy Lambda in VPC (needed for private MongoDB)"
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "VPC subnet IDs for Lambda (if enable_vpc is true)"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "VPC security group IDs for Lambda (if enable_vpc is true)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
