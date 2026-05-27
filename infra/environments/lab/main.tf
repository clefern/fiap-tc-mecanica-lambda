terraform {
  backend "s3" {
    bucket       = "fiap-tc-lab-tfstate"
    key          = "lab/lambda/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

module "lambda_auth" {
  source = "../../conf/"

  env     = "lab"
  region  = "us-east-1"
  profile = var.profile
  
  remote_state_bucket    = var.remote_state_bucket
  remote_state_infra_key = var.remote_state_infra_key
  remote_state_db_key    = var.remote_state_db_key
  remote_state_region    = var.remote_state_region
}
