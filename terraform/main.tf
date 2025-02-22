resource "aws_api_gateway_rest_api" "api" {
  name        = "ClashBot"
  description = "API Gateway for my application"
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
