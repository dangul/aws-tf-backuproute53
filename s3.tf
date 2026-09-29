resource "aws_s3_bucket" "backup_bucket" {
  count = var.create_s3_bucket ? 1 : 0

  bucket        = var.s3_bucket_name
  force_destroy = var.s3_bucket_force_destroy

  tags = {
    Purpose = "Route53 backup storage"
  }
}

resource "aws_s3_bucket_versioning" "backup_bucket_versioning" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.backup_bucket[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup_bucket_encryption" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.backup_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backup_bucket_public_access_block" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.backup_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backup_bucket_lifecycle" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.backup_bucket[0].id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}