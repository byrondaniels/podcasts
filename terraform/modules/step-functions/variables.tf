variable "state_machine_name" {
  description = "Name of the Step Functions state machine"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "audio_chunker_arn" {
  description = "ARN of the audio chunker Lambda function"
  type        = string
}

variable "transcribe_chunk_arn" {
  description = "ARN of the transcribe chunk Lambda function"
  type        = string
}

variable "merge_transcripts_arn" {
  description = "ARN of the merge transcripts Lambda function"
  type        = string
}
