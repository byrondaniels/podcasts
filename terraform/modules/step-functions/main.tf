# IAM Role for Step Functions
resource "aws_iam_role" "step_functions" {
  name = "${var.state_machine_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.state_machine_name}-role"
    Environment = var.environment
  }
}

# IAM Policy for Step Functions to invoke Lambda
resource "aws_iam_role_policy" "step_functions_lambda" {
  name = "${var.state_machine_name}-lambda-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.audio_chunker_arn,
          var.transcribe_chunk_arn,
          var.merge_transcripts_arn
        ]
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "podcast_processing" {
  name     = var.state_machine_name
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Podcast episode transcription workflow"
    StartAt = "DownloadAndChunk"
    States = {
      # Step 1: Download and Chunk Audio
      DownloadAndChunk = {
        Type         = "Task"
        Resource     = var.audio_chunker_arn
        Comment      = "Download audio file and split into chunks"
        TimeoutSeconds = 900  # 15 minutes
        ResultPath   = "$.chunkingResult"
        Retry = [
          {
            ErrorEquals = [
              "States.TaskFailed",
              "States.Timeout",
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException"
            ]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "HandleFailure"
          }
        ]
        Next = "PrepareForMapping"
      }

      # Prepare data for Map state
      PrepareForMapping = {
        Type = "Pass"
        Comment = "Prepare chunks array and preserve episode_id"
        Parameters = {
          "episode_id.$" = "$.episode_id"
          "chunks.$" = "$.chunkingResult.chunks"
          "s3_bucket.$" = "$.s3_bucket"
        }
        Next = "TranscribeChunks"
      }

      # Step 2: Transcribe Chunks in Parallel (Map State)
      TranscribeChunks = {
        Type           = "Map"
        ItemsPath      = "$.chunks"
        MaxConcurrency = 10
        ResultPath     = "$.transcripts"
        Iterator = {
          StartAt = "TranscribeChunk"
          States = {
            TranscribeChunk = {
              Type           = "Task"
              Resource       = var.transcribe_chunk_arn
              Comment        = "Transcribe individual audio chunk using Whisper API"
              TimeoutSeconds = 300  # 5 minutes per chunk
              Retry = [
                {
                  ErrorEquals = [
                    "States.TaskFailed",
                    "States.Timeout",
                    "Lambda.ServiceException",
                    "Lambda.AWSLambdaException",
                    "Lambda.SdkClientException"
                  ]
                  IntervalSeconds = 2
                  MaxAttempts     = 3
                  BackoffRate     = 2.0
                }
              ]
              Catch = [
                {
                  ErrorEquals = ["States.ALL"]
                  ResultPath  = "$.error"
                  Next        = "ChunkTranscriptionFailed"
                }
              ]
              End = true
            }

            ChunkTranscriptionFailed = {
              Type  = "Fail"
              Error = "ChunkTranscriptionError"
              Cause = "Failed to transcribe individual audio chunk after retries"
            }
          }
        }
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "HandleFailure"
          }
        ]
        Next = "MergeTranscripts"
      }

      # Step 3: Merge Transcripts
      MergeTranscripts = {
        Type           = "Task"
        Resource       = var.merge_transcripts_arn
        Comment        = "Combine all transcript chunks into final transcript"
        TimeoutSeconds = 300  # 5 minutes
        InputPath      = "$"
        ResultPath     = "$.mergeResult"
        Retry = [
          {
            ErrorEquals = [
              "States.TaskFailed",
              "States.Timeout",
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException"
            ]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "HandleFailure"
          }
        ]
        Next = "ProcessingComplete"
      }

      # Success State
      ProcessingComplete = {
        Type = "Pass"
        Comment = "Podcast episode processing completed successfully"
        Parameters = {
          "episode_id.$" = "$.episode_id"
          "status" = "completed"
          "final_transcript_key.$" = "$.mergeResult.final_transcript_key"
          "message" = "Transcription workflow completed successfully"
        }
        End = true
      }

      # Error Handling State
      HandleFailure = {
        Type = "Pass"
        Comment = "Mark episode as failed and prepare error response"
        Parameters = {
          "episode_id.$" = "$.episode_id"
          "status" = "failed"
          "error_info.$" = "$.error"
          "message" = "Transcription workflow failed"
        }
        Next = "WorkflowFailed"
      }

      # Final Failure State
      WorkflowFailed = {
        Type  = "Fail"
        Error = "PodcastProcessingError"
        Cause = "Podcast episode processing failed. Episode marked as failed in database."
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tags = {
    Name        = var.state_machine_name
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy.step_functions_lambda
  ]
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/states/${var.state_machine_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.state_machine_name}-logs"
    Environment = var.environment
  }
}
