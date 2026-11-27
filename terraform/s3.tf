# --- Random ID for Global S3 Bucket Uniqueness ---
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# --- S3 Bucket for Datasets & Model Artifacts ---
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-cloud-artifacts-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = false

  tags = {
    Name        = "${var.project_name}-cloud-artifacts"
    Description = "Storage for customer intelligence ML models and processed datasets"
  }
}

# --- Enable Bucket Versioning for ML Model Lineage & Rollback ---
resource "aws_s3_bucket_versioning" "artifacts_versioning" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --- Server-Side Encryption (SSE-S3) ---
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_encryption" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Block All Public Access ---
resource "aws_s3_bucket_public_access_block" "artifacts_public_block" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Lifecycle Configuration to Manage Historical Model Weights ---
resource "aws_s3_bucket_lifecycle_configuration" "artifacts_lifecycle" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "archive-old-model-versions"
    status = "Enabled"

    filter {
      prefix = "models/"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}
