# S3 Bucket for Audio Files and Chunks
resource "aws_s3_bucket" "audio" {
  bucket = var.audio_bucket_name

  tags = {
    Name        = var.audio_bucket_name
    Environment = var.environment
    Purpose     = "podcast-audio-storage"
  }
}

# S3 Bucket for Transcripts
resource "aws_s3_bucket" "transcripts" {
  bucket = var.transcript_bucket_name

  tags = {
    Name        = var.transcript_bucket_name
    Environment = var.environment
    Purpose     = "podcast-transcript-storage"
  }
}

# Versioning for Audio Bucket (optional but recommended)
resource "aws_s3_bucket_versioning" "audio" {
  bucket = aws_s3_bucket.audio.id

  versioning_configuration {
    status = "Disabled"  # Enable if you need version history
  }
}

# Versioning for Transcript Bucket
resource "aws_s3_bucket_versioning" "transcripts" {
  bucket = aws_s3_bucket.transcripts.id

  versioning_configuration {
    status = "Enabled"  # Keep versions of transcripts
  }
}

# Block public access for Audio Bucket
resource "aws_s3_bucket_public_access_block" "audio" {
  bucket = aws_s3_bucket.audio.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Block public access for Transcript Bucket
resource "aws_s3_bucket_public_access_block" "transcripts" {
  bucket = aws_s3_bucket.transcripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encryption for Audio Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "audio" {
  bucket = aws_s3_bucket.audio.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Encryption for Transcript Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "transcripts" {
  bucket = aws_s3_bucket.transcripts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle Policy for Audio Bucket - Delete chunks after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "audio" {
  bucket = aws_s3_bucket.audio.id

  rule {
    id     = "delete-audio-chunks"
    status = "Enabled"

    filter {
      prefix = "chunks/"
    }

    expiration {
      days = var.chunk_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "delete-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Lifecycle Policy for Transcript Bucket - Clean up old versions
resource "aws_s3_bucket_lifecycle_configuration" "transcripts" {
  bucket = aws_s3_bucket.transcripts.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "delete-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
