variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "whisper-audio-transcription"
}

variable "openai_api_key" {
  description = "OpenAI API key for Whisper API access"
  type        = string
  sensitive   = true
}

variable "s3_bucket" {
  description = "S3 bucket name for audio chunks and transcripts"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300  # 5 minutes
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "lambda_concurrency" {
  description = "Reserved concurrent executions for Lambda function"
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Log level for the Lambda function"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL"
  }
}

variable "enable_function_url" {
  description = "Enable Lambda function URL for direct invocation"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}
