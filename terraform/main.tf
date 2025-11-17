terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "podcast-transcription"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# SSM Parameters for secrets
module "ssm_parameters" {
  source = "./modules/ssm"

  mongodb_uri     = var.mongodb_uri
  openai_api_key  = var.openai_api_key
  environment     = var.environment
}

# S3 Buckets with lifecycle policies
module "s3_buckets" {
  source = "./modules/s3"

  environment         = var.environment
  audio_bucket_name   = "${var.project_name}-audio-${var.environment}"
  transcript_bucket_name = "${var.project_name}-transcripts-${var.environment}"
  chunk_expiration_days = 7
}

# Step Functions State Machine
module "step_functions" {
  source = "./modules/step-functions"

  environment           = var.environment
  state_machine_name    = "podcast-processing-workflow"
  audio_chunker_arn     = module.lambda_audio_chunker.lambda_arn
  transcribe_chunk_arn  = module.lambda_transcribe_chunk.lambda_arn
  merge_transcripts_arn = module.lambda_merge_transcripts.lambda_arn
}

# Lambda: RSS Poller
module "lambda_rss_poller" {
  source = "./modules/lambda"

  function_name   = "rss-feed-poller"
  handler         = "handler.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512
  source_dir      = "../poll-lambda"
  environment     = var.environment

  environment_variables = {
    MONGODB_URI_PARAM  = module.ssm_parameters.mongodb_uri_param_name
    STEP_FUNCTION_ARN  = module.step_functions.state_machine_arn
    AWS_REGION         = var.aws_region
    LOG_LEVEL          = var.log_level
  }

  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "states:StartExecution",
        "states:DescribeExecution"
      ]
      resources = [module.step_functions.state_machine_arn]
    },
    {
      effect = "Allow"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      resources = [
        module.ssm_parameters.mongodb_uri_param_arn
      ]
    }
  ]

  create_eventbridge_rule = true
  schedule_expression     = "rate(30 minutes)"
}

# Lambda: Audio Chunker
module "lambda_audio_chunker" {
  source = "./modules/lambda"

  function_name   = "podcast-audio-chunking"
  handler         = "handler.lambda_handler"
  runtime         = "python3.11"
  timeout         = 600
  memory_size     = 3008
  ephemeral_storage_size = 10240
  source_dir      = "../chunking-lambda"
  environment     = var.environment

  environment_variables = {
    MONGODB_URI_PARAM  = module.ssm_parameters.mongodb_uri_param_name
    S3_BUCKET          = module.s3_buckets.audio_bucket_name
    LOG_LEVEL          = var.log_level
  }

  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        module.s3_buckets.audio_bucket_arn,
        "${module.s3_buckets.audio_bucket_arn}/*"
      ]
    },
    {
      effect = "Allow"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      resources = [
        module.ssm_parameters.mongodb_uri_param_arn
      ]
    }
  ]
}

# Lambda: Transcribe Chunk (Whisper)
module "lambda_transcribe_chunk" {
  source = "./modules/lambda"

  function_name   = "whisper-audio-transcription"
  handler         = "handler.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512
  ephemeral_storage_size = 1024
  source_dir      = "../whisper-lambda/lambda"
  environment     = var.environment

  reserved_concurrent_executions = 10

  environment_variables = {
    OPENAI_API_KEY_PARAM = module.ssm_parameters.openai_api_key_param_name
    S3_BUCKET            = module.s3_buckets.audio_bucket_name
    LOG_LEVEL            = var.log_level
  }

  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      resources = [
        module.s3_buckets.audio_bucket_arn,
        "${module.s3_buckets.audio_bucket_arn}/*"
      ]
    },
    {
      effect = "Allow"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      resources = [
        module.ssm_parameters.openai_api_key_param_arn
      ]
    }
  ]
}

# Lambda: Merge Transcripts
module "lambda_merge_transcripts" {
  source = "./modules/lambda"

  function_name   = "merge-transcript-chunks"
  handler         = "handler.lambda_handler"
  runtime         = "python3.11"
  timeout         = 120
  memory_size     = 512
  source_dir      = "../merge-transcript-lambda/lambda"
  environment     = var.environment

  reserved_concurrent_executions = 5

  environment_variables = {
    MONGODB_URI_PARAM = module.ssm_parameters.mongodb_uri_param_name
    S3_BUCKET         = module.s3_buckets.audio_bucket_name
    LOG_LEVEL         = var.log_level
  }

  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        module.s3_buckets.audio_bucket_arn,
        "${module.s3_buckets.audio_bucket_arn}/*",
        module.s3_buckets.transcript_bucket_arn,
        "${module.s3_buckets.transcript_bucket_arn}/*"
      ]
    },
    {
      effect = "Allow"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      resources = [
        module.ssm_parameters.mongodb_uri_param_arn
      ]
    }
  ]
}
