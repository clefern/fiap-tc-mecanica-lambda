# terraform {
#   backend "s3" {
#     bucket = "fiap-tc-dev"
#     key    = "dev/lambda/terraform.tfstate"
#     region = "us-east-1"
#   }
# }

module "auth_lambda" {
  source = "../../conf/"

  env     = "develop"
  region  = "us-east-1"
  profile = var.profile

  jwt_secret = var.jwt_secret

  k8s_state_bucket = var.k8s_state_bucket
  k8s_state_key    = var.k8s_state_key
  k8s_state_region = var.k8s_state_region

  db_state_bucket = var.db_state_bucket
  db_state_key    = var.db_state_key
  db_state_region = var.db_state_region
}
