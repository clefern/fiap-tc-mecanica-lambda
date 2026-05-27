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

  lambda_role_arn = local.is_lab_env ? data.aws_iam_role.lab[0].arn : aws_iam_role.lambda_auth[0].arn

  # Path para o ZIP (default no root do repo)
  lambda_package_path = coalesce(var.lambda_package_path, "${path.module}/../../lambda.zip")

  execute_api_host = "${aws_api_gateway_rest_api.auth.id}.execute-api.${var.region}.amazonaws.com"
}
