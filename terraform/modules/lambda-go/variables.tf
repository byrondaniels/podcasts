variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 300
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "zip_file_path" {
  description = "Path to the pre-built Go Lambda zip file"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "policy_statements" {
  description = "List of IAM policy statements for the Lambda function"
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions for Lambda"
  type        = number
  default     = -1  # No reservation
}

variable "ephemeral_storage_size" {
  description = "Ephemeral storage size in MB (512-10240)"
  type        = number
  default     = 512
}

variable "create_eventbridge_rule" {
  description = "Whether to create an EventBridge rule for this Lambda"
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "EventBridge schedule expression"
  type        = string
  default     = ""
}
