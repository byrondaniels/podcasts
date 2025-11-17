variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for storing podcast audio chunks"
  type        = string
}

variable "mongodb_uri" {
  description = "MongoDB connection URI"
  type        = string
  sensitive   = true
}

variable "mongodb_db_name" {
  description = "MongoDB database name"
  type        = string
  default     = "podcast_db"
}

variable "lambda_image_uri" {
  description = "ECR image URI for Lambda function (format: account.dkr.ecr.region.amazonaws.com/repo:tag)"
  type        = string
  default     = ""  # Will be set after initial image push
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
