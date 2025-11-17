output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.merge_transcripts.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.merge_transcripts.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.merge_lambda_role.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda IAM role"
  value       = aws_iam_role.merge_lambda_role.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda_log_group.name
}

output "lambda_function_url" {
  description = "URL endpoint for the Lambda function (if enabled)"
  value       = var.enable_function_url ? aws_lambda_function_url.merge_url[0].function_url : null
}

output "lambda_invoke_arn" {
  description = "Invoke ARN for the Lambda function"
  value       = aws_lambda_function.merge_transcripts.invoke_arn
}
