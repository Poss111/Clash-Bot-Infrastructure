resource "aws_api_gateway_rest_api" "api" {
  name        = "ClashBot_Services_API"
  description = "High-performance API Gateway for ClashBot Services, enabling seamless integration and robust communication."
  binary_media_types = [
    "application/json",
    "application/octet-stream"
  ]
  disable_execute_api_endpoint = true

  tags = {
    Application = "ClashBot"
    Type        = "Shared"
    Repo        = "Clash-Bot-Infrastructure"
  }
}
