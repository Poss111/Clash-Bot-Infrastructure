variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_route_cidr" {
  description = "The CIDR block for the public route"
  type        = string
  default     = "0.0.0.0/0"
}
