variable "env" {
  description = "Environment name (develop, lab, prod) — prefix for Lambda and API Gateway"
  type        = string
}

variable "profile" {
  description = "AWS profile for the AWS provider (null in CI)"
  type        = string
  default     = null
  nullable    = true
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Extra tags for auth Lambda resources"
  type        = map(string)
  default     = {}
}

variable "jwt_secret" {
  description = "HS256 secret (Base64) — must match k8s Secret SECURITY_JWT_SECRET_KEY and Spring Boot"
  type        = string
  sensitive   = true
}

variable "lambda_package_path" {
  description = "Absolute path to lambda.zip (optional; default resolves from infra/conf to repo root)"
  type        = string
  default     = null
  nullable    = true
}

variable "access_token_ttl_seconds" {
  type    = string
  default = "3600"
}

# --- Remote state: fiap-tc-mecanica-infra-k8s (VPC + subnets) ---

variable "k8s_state_bucket" {
  description = "S3 bucket of the Kubernetes stack Terraform state"
  type        = string
}

variable "k8s_state_key" {
  description = "State object key inside the bucket (must match the K8s repo backend key)"
  type        = string
}

variable "k8s_state_region" {
  description = "Region of the S3 state bucket"
  type        = string
  default     = "us-east-1"
}

variable "k8s_state_dynamodb_table" {
  description = "DynamoDB table for state locking (omit if the K8s backend does not use one)"
  type        = string
  default     = null
  nullable    = true
}

variable "k8s_state_profile" {
  description = "AWS profile only for reading remote state (when different from var.profile)"
  type        = string
  default     = null
  nullable    = true
}

# --- Remote state: fiap-tc-mecanica-infra-db (RDS) ---

variable "db_state_bucket" {
  description = "S3 bucket of the RDS stack Terraform state"
  type        = string
}

variable "db_state_key" {
  description = "State object key for RDS (must match fiap-tc-mecanica-infra-db backend key)"
  type        = string
}

variable "db_state_region" {
  description = "Region of the RDS state bucket"
  type        = string
  default     = "us-east-1"
}

variable "db_state_dynamodb_table" {
  type     = string
  default  = null
  nullable = true
}

variable "db_state_profile" {
  type     = string
  default  = null
  nullable = true
}
