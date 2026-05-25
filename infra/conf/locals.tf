locals {
  is_lab_env = var.env == "lab"

  tags = merge(
    var.tags,
    {
      Environment = var.env
      Project     = "fiap-tc"
      Component   = "auth-lambda"
    }
  )

  remote_state_profile = (
    var.k8s_state_profile != null && var.k8s_state_profile != "" ? var.k8s_state_profile :
    var.profile != null && var.profile != "" ? var.profile :
    null
  )

  k8s_remote_state_config = merge(
    {
      bucket = var.k8s_state_bucket
      key    = var.k8s_state_key
      region = var.k8s_state_region
    },
    var.k8s_state_dynamodb_table != null && var.k8s_state_dynamodb_table != "" ? { dynamodb_table = var.k8s_state_dynamodb_table } : {},
    local.remote_state_profile != null ? { profile = local.remote_state_profile } : {}
  )

  db_remote_state_profile = (
    var.db_state_profile != null && var.db_state_profile != "" ? var.db_state_profile :
    local.remote_state_profile
  )

  db_remote_state_config = merge(
    {
      bucket = var.db_state_bucket
      key    = var.db_state_key
      region = var.db_state_region
    },
    var.db_state_dynamodb_table != null && var.db_state_dynamodb_table != "" ? { dynamodb_table = var.db_state_dynamodb_table } : {},
    local.db_remote_state_profile != null ? { profile = local.db_remote_state_profile } : {}
  )

  lambda_role_arn = local.is_lab_env ? data.aws_iam_role.lab[0].arn : aws_iam_role.lambda_auth[0].arn

  # path.module: zip lives at repo root (../../ from infra/conf). Plain "../../lambda.zip"
  # in a variable is resolved from the root module (environments/<env>), not from conf/.
  lambda_package_path = coalesce(var.lambda_package_path, "${path.module}/../../lambda.zip")

  execute_api_host = "${aws_api_gateway_rest_api.auth.id}.execute-api.${var.region}.amazonaws.com"
}
