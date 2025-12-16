# Unified Lambda Module Variables

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "handler" {
  description = "Lambda function handler (ignored for Go Lambdas)"
  type        = string
  default     = "handler.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime (use 'provided.al2023' for Go)"
  type        = string
  default     = "python3.11"
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

variable "architectures" {
  description = "Lambda architectures (x86_64 or arm64)"
  type        = list(string)
  default     = ["x86_64"]
}

# Deployment options - use one of these
variable "zip_file_path" {
  description = "Path to the Lambda zip file (for zip deployment)"
  type        = string
  default     = null
}

variable "docker_image_uri" {
  description = "ECR image URI for Docker deployment (without tag)"
  type        = string
  default     = null
}

variable "docker_image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "layer_arns" {
  description = "List of Lambda layer ARNs to attach"
  type        = list(string)
  default     = []
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
  description = "Reserved concurrent executions for Lambda (-1 for no limit)"
  type        = number
  default     = -1
}

variable "ephemeral_storage_size" {
  description = "Ephemeral storage size in MB (512-10240)"
  type        = number
  default     = 512
}

variable "enable_vpc" {
  description = "Whether to deploy Lambda in VPC"
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "VPC subnet IDs"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "VPC security group IDs"
  type        = list(string)
  default     = []
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
