provider "aws" {
  region = var.region

  profile = "Master"

  default_tags {
    tags = {
      Name = "ClashBotService"
      Type = "Shared"
    }
  }
}
