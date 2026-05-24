data "terraform_remote_state" "k8s" {
  backend = "s3"
  config  = local.k8s_remote_state_config
}

data "terraform_remote_state" "db" {
  backend = "s3"
  config  = local.db_remote_state_config
}
