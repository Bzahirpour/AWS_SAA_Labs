terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_s3_bucket" "test_static_site" {
  bucket_prefix = "test-static-site-"
  force_destroy = true

  tags = {
    Name        = "test static site bucket"
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "test_static_site" {
  bucket = aws_s3_bucket.test_static_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "test_static_site_policy" {
  bucket = aws_s3_bucket.test_static_site.id
  depends_on = [aws_s3_bucket_public_access_block.test_static_site]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.test_static_site.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "test_static_site_website" { # Configure the S3 bucket as a static website
  bucket = aws_s3_bucket.test_static_site.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

locals {
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
  key          = "img/${each.value}"
  source       = "${local.website_files}/img/${each.value}" # each.value is how you access the current item when looping with for_each
  etag         = filemd5("${local.website_files}/img/${each.value}")
  content_type = "image/jpeg"
}

output "website_url" {
  description = "Full clickable URL"
  value       = "http://${aws_s3_bucket_website_configuration.test_static_site_website.website_endpoint}" # website_endpoint is an attribute of the aws_s3_bucket_website_configuration resource that returns the endpoint URL for the S3 bucket website.
}