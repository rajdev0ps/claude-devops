# Terraform State Backend Infrastructure
# This file creates the S3 bucket and DynamoDB table needed for the remote backend
# Deploy this FIRST with local state, then switch to remote backend

# S3 bucket for Terraform state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-${data.aws_caller_identity.current.account_id}-${var.region}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Terraform State Storage"
  }
}

# Enable versioning on the state bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption on the state bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access to the state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable access logging on the state bucket
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_logs.id
  target_prefix = "state-bucket-logs/"
}

# Separate bucket for storing logs from the state bucket
resource "aws_s3_bucket" "terraform_logs" {
  bucket = "terraform-logs-${data.aws_caller_identity.current.account_id}-${var.region}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Terraform State Logs"
  }
}

# Block public access to logs bucket
resource "aws_s3_bucket_public_access_block" "terraform_logs" {
  bucket = aws_s3_bucket.terraform_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable encryption on logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_logs" {
  bucket = aws_s3_bucket.terraform_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB table for Terraform state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Terraform State Locking"
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Outputs for the backend configuration
output "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
  sensitive   = true
}

output "terraform_dynamodb_table" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}
