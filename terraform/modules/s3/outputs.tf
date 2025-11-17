output "audio_bucket_name" {
  description = "Name of the audio S3 bucket"
  value       = aws_s3_bucket.audio.id
}

output "audio_bucket_arn" {
  description = "ARN of the audio S3 bucket"
  value       = aws_s3_bucket.audio.arn
}

output "transcript_bucket_name" {
  description = "Name of the transcript S3 bucket"
  value       = aws_s3_bucket.transcripts.id
}

output "transcript_bucket_arn" {
  description = "ARN of the transcript S3 bucket"
  value       = aws_s3_bucket.transcripts.arn
}
