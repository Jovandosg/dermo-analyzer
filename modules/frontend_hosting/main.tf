# Frontend Hosting Module: modules/frontend_hosting/main.tf

variable "project_name" {
  description = "Project name for tagging resources."
  type        = string
}

variable "domain_name" {
  description = "The custom domain name for the frontend (e.g., cloudzen.com.br)."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS."
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 zone ID for creating alias records."
  type        = string
}

# S3 bucket for storing the React frontend static files
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-assets-${var.domain_name}" # Bucket names must be globally unique
  # acl    = "public-read" # Not recommended, use OAI/OAC and CloudFront

  tags = {
    Name    = "${var.project_name}-frontend-s3"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html" # Or a specific error.html page
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control (OAC) - preferred over OAI
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.project_name}-s3-oac"
  description                       = "OAC for ${var.project_name} frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 bucket policy to allow CloudFront access via OAC
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC",
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.frontend.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${var.project_name}-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.project_name} frontend"
  default_root_object = "index.html"

  # Aliases for custom domain
  aliases = [var.domain_name, "www.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.project_name}-frontend"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Price class (PriceClass_100 is cheapest - US, Canada, Europe)
  price_class = "PriceClass_100"

  # Viewer certificate for HTTPS
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none" # Or whitelist/blacklist specific countries
    }
  }

  # Logging (optional)
  # logging_config {
  #   include_cookies = false
  #   bucket          = "my-cloudfront-logs-bucket.s3.amazonaws.com"
  #   prefix          = "${var.project_name}-frontend-cf-logs/"
  # }

  tags = {
    Name    = "${var.project_name}-cf-frontend"
    Project = var.project_name
  }
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "The Route 53 hosted zone ID for CloudFront distributions (this is a static value)."
  value       = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
}

output "frontend_s3_bucket_name" {
  description = "The name of the S3 bucket hosting the frontend static assets."
  value       = aws_s3_bucket.frontend.bucket
}

