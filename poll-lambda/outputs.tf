output "lambda_function_arn" {
  description = "ARN of the RSS feed poller Lambda function"
  value       = aws_lambda_function.rss_poller.arn
}

output "lambda_function_name" {
  description = "Name of the RSS feed poller Lambda function"
  value       = aws_lambda_function.rss_poller.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_role.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.rss_poller_schedule.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.rss_poller_schedule.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.rss_poller.name
}

output "lambda_layer_arn" {
  description = "ARN of the Lambda layer (if created)"
  value       = var.create_lambda_layer ? aws_lambda_layer_version.dependencies[0].arn : null
}

output "error_alarm_arn" {
  description = "ARN of the Lambda errors CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_errors.arn
}

output "duration_alarm_arn" {
  description = "ARN of the Lambda duration CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_duration.arn
}
