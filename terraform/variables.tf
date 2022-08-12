variable "access_key" {
  description = "Access Key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Secret Key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS Region"
  default     = "us-east-1"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Domain that cf is under"
  type        = string
  sensitive   = true
}

variable "custom_header" {
  type      = string
  sensitive = true
}

variable "custom_header_value" {
  type      = string
  sensitive = true
}

