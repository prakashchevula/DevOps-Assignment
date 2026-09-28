# Task 2 — remote state + locking
# Bucket/table names must be static strings in the backend block (backend loads before resources).
# Chicken-and-egg: the bucket and table must exist BEFORE `terraform init` with this backend.
# See task2-NOTES.md for the first-time bootstrap steps.

terraform {
  backend "s3" {
    bucket         = "tfstate-devops-assignment-pchevula"
    key            = "task1/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "tfstate-lock-devops-assignment"
    encrypt        = true
  }
}

# State bucket + lock table (create these first with local state, then enable the backend above).
resource "aws_s3_bucket" "tfstate" {
  bucket = "tfstate-devops-assignment-pchevula"

  tags = {
    Name        = "tfstate-devops-assignment-pchevula"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "tfstate-lock-devops-assignment"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "tfstate-lock-devops-assignment"
    Environment = var.environment
    Owner       = var.owner
  }
}
