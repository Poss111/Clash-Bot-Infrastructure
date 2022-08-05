output "cloudfront_url" {
  value       = aws_cloudfront_distribution.clash_bot_distribution.domain_name
  description = "Cloudfront url"
}

output "webapp_s3_bucket" {
  value       = aws_s3_bucket.clash-bot-webapp-s3-bucket.bucket
  description = "Clash Bot Webapp S3 bucket"
}

output "cf_logs_s3_bucket" {
  value       = aws_s3_bucket.clash-bot-cf-logs-bucket.bucket
  description = "Cloudfront logs S3 bucket"
}

