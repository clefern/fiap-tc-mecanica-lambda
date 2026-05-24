# State separado do cluster e do RDS (mesmo bucket, key distinta).
# Bucket S3: infra/environments/lab/backend.hcl (gerado por scripts/bootstrap_tf_lab.sh).
terraform {
  backend "s3" {}
}

module "auth_lambda" {
  source = "../../conf/"

  env     = "lab"
  region  = "us-east-1"
  profile = var.profile

  jwt_secret = var.jwt_secret

  k8s_state_bucket         = var.tf_state_bucket
  k8s_state_key            = "lab/terraform.tfstate"
  k8s_state_region         = "us-east-1"
  k8s_state_dynamodb_table = "terraform-lock-table"

  db_state_bucket         = var.tf_state_bucket
  db_state_key            = "lab/db/terraform.tfstate"
  db_state_region         = "us-east-1"
  db_state_dynamodb_table = "terraform-lock-table"
}
