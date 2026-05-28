# S3 Bucket for static site hosting (private)
resource "aws_s3_bucket" "site_bucket" {
  bucket = "${var.project_name}-${var.environment}-site"

  tags = local.common_tags
}

# Block all public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "site_bucket_pab" {
  bucket = aws_s3_bucket.site_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Expire non-current object versions after 90 days to reduce storage cost
resource "aws_s3_bucket_lifecycle_configuration" "site_bucket" {
  bucket = aws_s3_bucket.site_bucket.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {} # applies to all objects in the bucket

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Enable encryption on the site bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "site_bucket_sse" {
  bucket = aws_s3_bucket.site_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# CloudFront Origin Access Control (OAC) for S3
resource "aws_cloudfront_origin_access_control" "site_oac" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "Origin Access Control for ${var.project_name} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Bucket Policy - Allow CloudFront OAC to read objects
resource "aws_s3_bucket_policy" "site_bucket_policy" {
  bucket = aws_s3_bucket.site_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.site_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site_distribution.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.site_bucket_pab]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "site_distribution" {
  origin {
    domain_name              = aws_s3_bucket.site_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site_oac.id
    origin_id                = "S3Origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class

  lifecycle {
    ignore_changes = [web_acl_id]
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3Origin"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    viewer_protocol_policy = "redirect-to-https"
  }

  # Custom error response for 404 errors
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  # Custom error response for 403 errors
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.common_tags
}

# Data source for CloudFront Managed Cache Policy (CachingOptimized)
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}
