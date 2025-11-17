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
    Comment = "Podcast Processing Workflow: Chunk audio, transcribe chunks in parallel, and merge transcripts"
    StartAt = "ChunkAudio"
    States = {
      ChunkAudio = {
        Type     = "Task"
        Resource = var.audio_chunker_arn
        Comment  = "Split audio file into 10-minute chunks"
        Retry = [
          {
            ErrorEquals = [
              "States.TaskFailed",
              "States.Timeout"
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
            Next        = "ChunkingFailed"
          }
        ]
        Next = "TranscribeChunks"
      }

      TranscribeChunks = {
        Type       = "Map"
        ItemsPath  = "$.chunks"
        MaxConcurrency = 10
        Iterator = {
          StartAt = "TranscribeChunk"
          States = {
            TranscribeChunk = {
              Type     = "Task"
              Resource = var.transcribe_chunk_arn
              Comment  = "Transcribe a single audio chunk using Whisper API"
              Retry = [
                {
                  ErrorEquals = [
                    "States.TaskFailed"
                  ]
                  IntervalSeconds = 5
                  MaxAttempts     = 3
                  BackoffRate     = 2.0
                },
                {
                  ErrorEquals = [
                    "States.Timeout"
                  ]
                  IntervalSeconds = 2
                  MaxAttempts     = 2
                  BackoffRate     = 1.5
                }
              ]
              Catch = [
                {
                  ErrorEquals = ["States.ALL"]
                  ResultPath  = "$.error"
                  Next        = "TranscriptionFailed"
                }
              ]
              End = true
            }

            TranscriptionFailed = {
              Type  = "Fail"
              Error = "TranscriptionError"
              Cause = "Failed to transcribe audio chunk"
            }
          }
        }
        ResultPath = "$.transcriptionResults"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "TranscriptionMapFailed"
          }
        ]
        Next = "MergeTranscripts"
      }

      MergeTranscripts = {
        Type     = "Task"
        Resource = var.merge_transcripts_arn
        Comment  = "Combine all transcript chunks into final transcript"
        Retry = [
          {
            ErrorEquals = [
              "States.TaskFailed",
              "States.Timeout"
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
            Next        = "MergeFailed"
          }
        ]
        End = true
      }

      ChunkingFailed = {
        Type  = "Fail"
        Error = "ChunkingError"
        Cause = "Failed to chunk audio file"
      }

      TranscriptionMapFailed = {
        Type  = "Fail"
        Error = "TranscriptionMapError"
        Cause = "Failed during parallel transcription of chunks"
      }

      MergeFailed = {
        Type  = "Fail"
        Error = "MergeError"
        Cause = "Failed to merge transcript chunks"
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
