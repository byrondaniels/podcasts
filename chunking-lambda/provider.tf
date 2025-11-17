provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Podcast Processing"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
