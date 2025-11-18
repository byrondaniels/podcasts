output "lambda_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.function.arn
}

output "lambda_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.function.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.function.invoke_arn
}
