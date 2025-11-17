output "mongodb_uri_param_name" {
  description = "Name of the MongoDB URI SSM parameter"
  value       = aws_ssm_parameter.mongodb_uri.name
}

output "mongodb_uri_param_arn" {
  description = "ARN of the MongoDB URI SSM parameter"
  value       = aws_ssm_parameter.mongodb_uri.arn
}

output "openai_api_key_param_name" {
  description = "Name of the OpenAI API key SSM parameter"
  value       = aws_ssm_parameter.openai_api_key.name
}

output "openai_api_key_param_arn" {
  description = "ARN of the OpenAI API key SSM parameter"
  value       = aws_ssm_parameter.openai_api_key.arn
}
