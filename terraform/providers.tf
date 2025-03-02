provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Name = "ClashBotService"
      Type = "Shared"
    }
  }
}
