# Step 1: Get the existing Route 53 hosted zone
data "aws_route53_zone" "existing_zone" {
  name         = "clash-bot.ninja"
  private_zone = false # Set to true if it's a private hosted zone
}

# Step 2: Create an ACM Certificate for API Gateway
resource "aws_acm_certificate" "api_cert" {
  domain_name       = "api.clash-bot.ninja"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Step 3: Create DNS validation record for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.existing_zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}



# Step 4: Validate the certificate
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.api_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Step 5: Create the API Gateway V2 custom domain
resource "aws_apigatewayv2_domain_name" "custom_domain" {
  domain_name = "api.clash-bot.ninja"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api" "api" {
  name                         = "ClashBot_Services_API"
  protocol_type                = "HTTP"
  description                  = "High-performance API Gateway for ClashBot Services, enabling seamless integration and robust communication."
  disable_execute_api_endpoint = false

  tags = {
    Application = "ClashBot"
    Type        = "Shared"
    Repo        = "Clash-Bot-Infrastructure"
  }
}

# Step 7: Map the custom domain to API Gateway
resource "aws_apigatewayv2_api_mapping" "api_mapping" {
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.custom_domain.id
  stage       = "$default" # Use the actual deployment stage name
}

# Step 8: Create a Route 53 Alias Record for API Gateway
resource "aws_route53_record" "api_dns" {
  zone_id = data.aws_route53_zone.existing_zone.zone_id
  name    = "api.clash-bot.ninja"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.custom_domain.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.custom_domain.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
