output "s3_audio_bucket_name" {
  description = "Name of the S3 bucket for audio files and chunks"
  value       = module.s3_buckets.audio_bucket_name
}

output "s3_audio_bucket_arn" {
  description = "ARN of the S3 bucket for audio files and chunks"
  value       = module.s3_buckets.audio_bucket_arn
}

output "s3_transcript_bucket_name" {
  description = "Name of the S3 bucket for transcripts"
  value       = module.s3_buckets.transcript_bucket_name
}

output "s3_transcript_bucket_arn" {
  description = "ARN of the S3 bucket for transcripts"
  value       = module.s3_buckets.transcript_bucket_arn
}

output "step_function_arn" {
  description = "ARN of the Step Functions state machine"
  value       = module.step_functions.state_machine_arn
}

output "step_function_name" {
  description = "Name of the Step Functions state machine"
  value       = module.step_functions.state_machine_name
}

output "lambda_rss_poller_arn" {
  description = "ARN of the RSS poller Lambda function"
  value       = module.lambda_rss_poller.lambda_arn
}

output "lambda_rss_poller_name" {
  description = "Name of the RSS poller Lambda function"
  value       = module.lambda_rss_poller.lambda_name
}

output "lambda_audio_chunker_arn" {
  description = "ARN of the audio chunker Lambda function"
  value       = module.lambda_audio_chunker.lambda_arn
}

output "lambda_audio_chunker_name" {
  description = "Name of the audio chunker Lambda function"
  value       = module.lambda_audio_chunker.lambda_name
}

output "lambda_transcribe_chunk_arn" {
  description = "ARN of the transcribe chunk Lambda function"
  value       = module.lambda_transcribe_chunk.lambda_arn
}

output "lambda_transcribe_chunk_name" {
  description = "Name of the transcribe chunk Lambda function"
  value       = module.lambda_transcribe_chunk.lambda_name
}

output "lambda_merge_transcripts_arn" {
  description = "ARN of the merge transcripts Lambda function"
  value       = module.lambda_merge_transcripts.lambda_arn
}

output "lambda_merge_transcripts_name" {
  description = "Name of the merge transcripts Lambda function"
  value       = module.lambda_merge_transcripts.lambda_name
}

output "ssm_mongodb_uri_param_name" {
  description = "SSM Parameter Store name for MongoDB URI"
  value       = module.ssm_parameters.mongodb_uri_param_name
}

output "ssm_openai_api_key_param_name" {
  description = "SSM Parameter Store name for OpenAI API key"
  value       = module.ssm_parameters.openai_api_key_param_name
}
