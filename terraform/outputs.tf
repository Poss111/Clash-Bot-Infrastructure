output "cloudfront_url" {
  value       = aws_cloudfront_distribution.clash_bot_distribution.domain_name
  description = "Cloudfront url"
}

output "cf_logs_s3_bucket" {
  value       = aws_s3_bucket.clash-bot-cf-logs-bucket.bucket
  description = "Cloudfront logs S3 bucket"
}

output "host_zone_id" {
  value       = aws_route53_record.clash-bot-record-a.zone_id
  description = "Hosted Zone Record"
}

output "host_zone_name" {
  value       = aws_route53_record.clash-bot-record-a.name
  description = "Hosted Zone Record"
}

