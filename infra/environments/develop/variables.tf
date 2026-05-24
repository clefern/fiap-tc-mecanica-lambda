variable "profile" {
  description = "AWS profile (null in CI)"
  type        = string
  default     = null
  nullable    = true
}

variable "jwt_secret" {
  description = "HS256 secret (Base64) — same as k8s SECURITY_JWT_SECRET_KEY"
  type        = string
  sensitive   = true
}

variable "k8s_state_bucket" {
  type    = string
  default = "fiap-tc-dev"
}

variable "k8s_state_key" {
  type    = string
  default = "dev/terraform.tfstate"
}

variable "k8s_state_region" {
  type    = string
  default = "us-east-1"
}

variable "db_state_bucket" {
  type    = string
  default = "fiap-tc-dev"
}

variable "db_state_key" {
  type    = string
  default = "dev/db/terraform.tfstate"
}

variable "db_state_region" {
  type    = string
  default = "us-east-1"
}
