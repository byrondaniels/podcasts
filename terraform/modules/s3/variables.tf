variable "audio_bucket_name" {
  description = "Name of the S3 bucket for audio files and chunks"
  type        = string
}

variable "transcript_bucket_name" {
  description = "Name of the S3 bucket for transcripts"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "chunk_expiration_days" {
  description = "Number of days before audio chunks are deleted"
  type        = number
  default     = 7
}
