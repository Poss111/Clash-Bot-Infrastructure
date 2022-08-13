terraform {
  cloud {
    organization = "ClashBot"

    workspaces {
      name = "ClashBot-Infrastructure"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.21.0"
    }
  }
}

data "tfe_outputs" "clash-bot-webapp" {
  organization = "ClashBot"
  workspace    = "ClashBot-Webapp"
}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region

  default_tags {
    tags = {
      Application = "Clash-Bot-Infrastructure"
      Type        = "Infrastructure"
    }
  }
}

resource "aws_s3_bucket" "clash-bot-webapp-s3-bucket" {
  bucket = "clash-bot-webapp-s3-bucket"
}

resource "aws_s3_bucket_policy" "clash-bot-webapp-s3-bucket-policy" {
  bucket = aws_s3_bucket.clash-bot-webapp-s3-bucket.id
  policy = data.aws_iam_policy_document.static_hosting_policy.json
}

data "aws_iam_policy_document" "static_hosting_policy" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.clash-bot-webapp-s3-bucket.arn,
      "${aws_s3_bucket.clash-bot-webapp-s3-bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_acl" "clash_bot_webapp_s3_bucket" {
  bucket = aws_s3_bucket.clash-bot-webapp-s3-bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "clash_bot_webapp_s3_website_conf" {
  bucket = aws_s3_bucket.clash-bot-webapp-s3-bucket.bucket

  index_document {
    suffix = "index.html"
  }

  routing_rule {
    condition {
      http_error_code_returned_equals = "404"
    }
    redirect {
      host_name        = var.domain
      protocol         = "https"
      replace_key_with = "index.html"
    }
  }
}

resource "aws_s3_bucket" "clash-bot-cf-logs-bucket" {
  bucket        = "clash-bot-cf-logs-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "clash-bot-webapp-bucket_acl" {
  bucket = aws_s3_bucket.clash-bot-webapp-s3-bucket.id
  acl    = "private"
}

locals {
  s3_origin_id = "S3-www.${aws_s3_bucket.clash-bot-webapp-s3-bucket.id}"
}

data "aws_acm_certificate" "clash-bot-cer" {
  domain   = var.domain
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_cache_policy" "clash-bot-service-cf-cp" {
  name        = "clash-bot-service-cp"
  comment     = "This is to query for the user information from the service."
  default_ttl = 1
  max_ttl     = 1
  min_ttl     = 1
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "clash-bot-service-rp" {
  name    = "clash-bot-service-request-policy"
  comment = "This is to query for the user information from the service."
  cookies_config {
    cookie_behavior = "none"
  }
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Sec-WebSocket-Key", "Sec-WebSocket-Version", "Host", "Sec-WebSocket-Protocol", "Sec-WebSocket-Accept"]
    }
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_distribution" "clash_bot_distribution" {
  origin {
    domain_name = aws_s3_bucket.clash-bot-webapp-s3-bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  origin {
    domain_name = data.tfe_outputs.clash-bot-webapp.values.webapp_lb_url
    origin_id   = "clash-bot-webapp-lb"

    custom_origin_config {
      http_port              = var.lb_port
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1"]
    }

    custom_header {
      name  = var.custom_header
      value = var.custom_header_value
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Cloudfront distribution to handle the Clash Bot Webapp"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.clash-bot-cf-logs-bucket.bucket_domain_name
    prefix          = "cf-clash-bot"
  }

  ordered_cache_behavior {
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    path_pattern             = "/api*"
    target_origin_id         = "clash-bot-webapp-lb"
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = aws_cloudfront_cache_policy.clash-bot-service-cf-cp.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.clash-bot-service-rp.id
  }

  ordered_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    path_pattern           = "/ws*"
    target_origin_id       = "clash-bot-webapp-lb"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["HEAD", "GET", "OPTIONS"]
    target_origin_id = local.s3_origin_id

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
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.clash-bot-cer.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
