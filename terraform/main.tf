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

data "aws_route53_zone" "clash-zone" {
  name = var.hosted_zone_name
}

resource "aws_route53_record" "clash-bot-record-a" {
  zone_id = data.aws_route53_zone.clash-zone.zone_id
  name    = var.hosted_zone_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.clash_bot_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.clash_bot_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_lb" "clash-bot-webapp-lb" {
  arn = var.clash_bot_webapp_lb_arn
}

resource "aws_s3_bucket" "clash-bot-cf-logs-bucket" {
  bucket        = "clash-bot-cf-logs-bucket"
  force_destroy = true
}

locals {
  s3_origin_id = "S3-www.clash-bot-webapp"
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
  aliases             = [var.hosted_zone_name]
  default_root_object = "index.html"
  origin {
    domain_name = var.statically_hosted_s3_bucket
    origin_id   = local.s3_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  origin {
    domain_name = data.aws_lb.clash-bot-webapp-lb.dns_name
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
    cache_policy_id  = aws_cloudfront_cache_policy.clash-bot-service-cf-cp.id

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
