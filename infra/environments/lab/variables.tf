variable "profile" {
  description = "AWS profile (null in CI — use env credentials)"
  type        = string
  default     = "fiap-lab"
  nullable    = true
}

variable "jwt_secret" {
  description = "HS256 secret (Base64) — same as k8s SECURITY_JWT_SECRET_KEY"
  type        = string
  sensitive   = true
}

variable "tf_state_bucket" {
  description = "S3 bucket for this stack and for reading k8s/db remote state (export TF_STATE_BUCKET or use bootstrap_tf_lab.sh)"
  type        = string
}
