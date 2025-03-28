
# Step 5: Create the API Gateway V2 custom domain
resource "aws_apigatewayv2_domain_name" "ws_custom_domain" {
  domain_name = "ws.clash-bot.ninja"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api" "ws_api" {
  name                         = "ClashBot_Services_WS"
  protocol_type                = "WEBSOCKET"
  description                  = "High-performance API Gateway for ClashBot Services, enabling seamless integration and robust communication."
  route_selection_expression = "$request.body.action"

  tags = {
    Application = "ClashBot"
    Type        = "Shared"
    Repo        = "Clash-Bot-Infrastructure"
  }
}

# Create a default route ($default)
resource "aws_apigatewayv2_route" "ws_default_route" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$default"
  target    = "integrations/TO_BE_DEFINED_IN_PULUMI"
}

# Step 7: Map the custom domain to API Gateway
resource "aws_apigatewayv2_api_mapping" "ws_api_mapping" {
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.custom_domain.id
  stage       = "$default"
}

# Step 8: Create a Route 53 Alias Record for API Gateway
resource "aws_route53_record" "ws_dns" {
  zone_id = data.aws_route53_zone.existing_zone.zone_id
  name    = "ws.clash-bot.ninja"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.custom_domain.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.custom_domain.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
