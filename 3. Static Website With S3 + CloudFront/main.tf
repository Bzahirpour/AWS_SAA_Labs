terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "test_static_site" {
  bucket_prefix = "test-static-site-"
  force_destroy = true

  tags = {
    Name        = "test static site bucket"
    Environment = "production"
  }
}

resource "aws_s3_bucket_policy" "origin_bucket_policy" {
  bucket = aws_s3_bucket.test_static_site.id
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}

resource "aws_s3_bucket_public_access_block" "test_static_site" {
  bucket = aws_s3_bucket.test_static_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
   s3_origin_id = "s3-origin" # This is an arbitrary string that serves as an identifier for the S3 origin in the CloudFront distribution. It can be any unique value, but it must match the origin_id specified in the aws_cloudfront_distribution resource.
  website_files = "${path.module}/website_files" #path.module is a built-in Terraform variable that returns the filesystem path to the directory where the current .tf file lives.
  
  content_types = {
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "jpg"  = "image/jpeg"
    "png"  = "image/png"
    "gif"  = "image/gif"
  }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.test_static_site.id
  key          = "index.html"
  source       = "${local.website_files}/index.html"
  etag         = filemd5("${local.website_files}/index.html")
  content_type = "text/html"
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.test_static_site.id
  key          = "error.html"
  source       = "${local.website_files}/error.html"
  etag         = filemd5("${local.website_files}/error.html")
  content_type = "text/html"
}

resource "aws_s3_object" "images" {
  for_each = fileset("${local.website_files}/img", "*.jpg") # for_each is a for loop

  bucket       = aws_s3_bucket.test_static_site.id
  key          = "img/${each.value}" #
  source       = "${local.website_files}/img/${each.value}" # each.value is how you access the current item when looping with for_each
  etag         = filemd5("${local.website_files}/img/${each.value}")
  content_type = lookup(local.content_types, split(".", each.value)[1], "application/octet-stream") # split(".", each.value)[1] is a way to get the file extension from the filename, and lookup is used to get the corresponding content type from the local.content_types map.
}

output "website_url" {
  description = "Full clickable URL"
  value       = "http://${aws_cloudfront_distribution.s3_distribution.domain_name}" # aws_cloudfront_distribution.s3_distribution.domain_name is the domain name of the CloudFront distribution, which will be used to access the static website.
}

# See https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html
data "aws_iam_policy_document" "origin_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.test_static_site.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  viewer_certificate {
  cloudfront_default_certificate = true
}

  custom_error_response {
  error_code         = 404
  response_code      = 404
  response_page_path = "/error.html"
}

  origin {
    domain_name              = aws_s3_bucket.test_static_site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.s3_origin_id
    }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 static website distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }
}