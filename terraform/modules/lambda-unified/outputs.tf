# Unified Lambda Module Outputs

output "lambda_arn" {
  description = "ARN of the Lambda function"
  value       = local.lambda_function.arn
}

output "lambda_name" {
  description = "Name of the Lambda function"
  value       = local.lambda_function.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda.name
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = local.lambda_function.invoke_arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.lambda.arn
}
