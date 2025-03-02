resource "aws_apigatewayv2_api" "api" {
  name                         = "ClashBot_Services_API"
  protocol_type                = "HTTP"
  description                  = "High-performance API Gateway for ClashBot Services, enabling seamless integration and robust communication."
  disable_execute_api_endpoint = true

  tags = {
    Application = "ClashBot"
    Type        = "Shared"
    Repo        = "Clash-Bot-Infrastructure"
  }
}
