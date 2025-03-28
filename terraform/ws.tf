# Step 2: Create an ACM Certificate for API Gateway
resource "aws_acm_certificate" "ws_cert" {
  domain_name       = "ws.clash-bot.ninja"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Step 3: Create DNS validation record for ACM certificate
resource "aws_route53_record" "ws_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ws_cert.domain_validation_options : dvo.domain_name => {
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
resource "aws_acm_certificate_validation" "ws_cert" {
  certificate_arn         = aws_acm_certificate.ws_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.ws_cert_validation : record.fqdn]
}


# Step 5: Create the API Gateway V2 custom domain
resource "aws_apigatewayv2_domain_name" "ws_custom_domain" {
  domain_name = "ws.clash-bot.ninja"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.ws_cert.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api" "ws_api" {
  name                       = "ClashBot_Services_WS"
  protocol_type              = "WEBSOCKET"
  description                = "WebSocket API Gateway for ClashBot Services, enabling real-time communication and seamless integration."
  route_selection_expression = "$request.body.action"

  tags = {
    Application = "ClashBot"
    Type        = "Shared"
    Repo        = "Clash-Bot-Infrastructure"
  }
}

# Create a default route ($default)
resource "aws_apigatewayv2_route" "ws_default_route" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Step 7: Map the custom domain to API Gateway
resource "aws_apigatewayv2_api_mapping" "ws_api_mapping" {
  api_id      = aws_apigatewayv2_api.ws_api.id
  domain_name = aws_apigatewayv2_domain_name.ws_custom_domain.id
  stage       = "$default"
}

# Step 8: Create a Route 53 Alias Record for API Gateway
resource "aws_route53_record" "ws_dns" {
  zone_id = data.aws_route53_zone.existing_zone.zone_id
  name    = "ws.clash-bot.ninja"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.ws_custom_domain.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.ws_custom_domain.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_lambda_function" "websocket_handler" {
  function_name = var.lambda_name
}

# Create the integration between API Gateway and Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.ws_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = data.aws_lambda_function.websocket_handler.invoke_arn
}

# Deploy the API
resource "aws_apigatewayv2_deployment" "websocket_deployment" {
  api_id = aws_apigatewayv2_api.ws_api.id

  depends_on = [
    aws_apigatewayv2_route.ws_default_route
  ]
}

# Create a stage for the WebSocket API
resource "aws_apigatewayv2_stage" "websocket_stage" {
  api_id        = aws_apigatewayv2_api.ws_api.id
  name          = "$default"
  deployment_id = aws_apigatewayv2_deployment.websocket_deployment.id
}

# Permissions: Allow API Gateway to invoke the Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.websocket_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws_api.execution_arn}/*/*"
}
