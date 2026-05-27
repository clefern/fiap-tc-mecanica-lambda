data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = var.remote_state_bucket
    key    = var.remote_state_infra_key
    region = var.remote_state_region
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.remote_state_bucket
    key    = var.remote_state_db_key
    region = var.remote_state_region
  }
}
