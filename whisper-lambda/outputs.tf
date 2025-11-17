output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.whisper_transcription.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.whisper_transcription.function_name
}

output "lambda_function_qualified_arn" {
  description = "Qualified ARN of the Lambda function (includes version)"
  value       = aws_lambda_function.whisper_transcription.qualified_arn
}

output "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda function"
  value       = aws_iam_role.whisper_lambda_role.arn
}

output "lambda_role_name" {
  description = "Name of the IAM role for Lambda function"
  value       = aws_iam_role.whisper_lambda_role.name
}

output "lambda_function_url" {
  description = "Lambda function URL (if enabled)"
  value       = var.enable_function_url ? aws_lambda_function_url.whisper_url[0].function_url : null
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_log_group.name
}

output "lambda_invoke_command" {
  description = "AWS CLI command to invoke the Lambda function"
  value       = <<-EOT
    aws lambda invoke \
      --function-name ${aws_lambda_function.whisper_transcription.function_name} \
      --payload '{"episode_id": "ep123", "chunk_index": 0, "s3_key": "chunks/ep123/chunk_0.mp3", "start_time_seconds": 0}' \
      --region ${data.aws_region.current.name} \
      response.json
  EOT
}
