variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "podcast"
}

variable "mongodb_uri" {
  description = "MongoDB connection URI (will be stored in SSM Parameter Store)"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key for Whisper API (will be stored in SSM Parameter Store)"
  type        = string
  sensitive   = true
}

variable "log_level" {
  description = "Logging level for Lambda functions"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL"
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
