# S3 Module: modules/s3/main.tf

variable "bucket_name" {
  description = "Name for the S3 bucket. Must be globally unique."
  type        = string
}

variable "project_name" {
  description = "Project name for tagging resources."
  type        = string
}

variable "acl" {
  description = "The canned ACL to apply. Defaults to private."
  type        = string
  default     = "private"
}

variable "versioning_enabled" {
  description = "A state of versioning. Defaults to true."
  type        = bool
  default     = true
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  # acl    = var.acl # ACLs are deprecated for new buckets, use bucket policies and IAM

  tags = {
    Name    = "${var.project_name}-s3-bucket-${var.bucket_name}"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration to allow uploads from the frontend application
resource "aws_s3_bucket_cors_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE"] # Adjust as needed, GET for presigned URL access
    allowed_origins = ["*"] # Replace with your actual frontend domain in production e.g. https://cloudzen.com.br
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Bucket policy (example: allow Lambda to GetObject and PutObject)
# This will be more specific based on Lambda IAM role later
# For now, we focus on the bucket creation and basic settings.
# A more refined policy would be attached via the IAM module or Lambda module.

output "s3_bucket_id" {
  description = "The ID (name) of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "s3_bucket_domain_name" {
  description = "The domain name of the S3 bucket."
  value       = aws_s3_bucket.this.bucket_domain_name
}

