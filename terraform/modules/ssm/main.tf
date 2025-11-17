# SSM Parameter for MongoDB URI
resource "aws_ssm_parameter" "mongodb_uri" {
  name        = "/podcast-app/mongodb-uri"
  description = "MongoDB connection URI for podcast application"
  type        = "SecureString"
  value       = var.mongodb_uri

  tags = {
    Name        = "mongodb-uri"
    Environment = var.environment
  }
}

# SSM Parameter for OpenAI API Key
resource "aws_ssm_parameter" "openai_api_key" {
  name        = "/podcast-app/openai-api-key"
  description = "OpenAI API key for Whisper transcription"
  type        = "SecureString"
  value       = var.openai_api_key

  tags = {
    Name        = "openai-api-key"
    Environment = var.environment
  }
}
