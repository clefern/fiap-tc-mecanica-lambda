resource "aws_security_group" "lambda_auth" {
  name        = "${var.env}-lambda-auth-sg"
  description = "Security group for Lambda Auth"
  vpc_id      = data.terraform_remote_state.infra.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_lambda_function" "auth" {
  function_name    = "${var.env}-${var.lambda_function_name}"
  role             = local.lambda_role_arn
  handler          = "handler.handler"
  runtime          = "nodejs20.x"
  architectures    = ["arm64"]
  timeout          = 10
  memory_size      = 256

  filename         = local.lambda_package_path
  source_code_hash = filebase64sha256(local.lambda_package_path)

  vpc_config {
    subnet_ids         = data.terraform_remote_state.infra.outputs.subnet_ids
    security_group_ids = [aws_security_group.lambda_auth.id]
  }

  environment {
    variables = {
      DB_HOST                   = data.terraform_remote_state.db.outputs.rds_endpoint
      DB_PORT                   = tostring(data.terraform_remote_state.db.outputs.rds_port)
      DB_NAME                   = data.terraform_remote_state.db.outputs.rds_db_name
      DB_USERNAME               = data.terraform_remote_state.db.outputs.rds_master_username
      DB_PASSWORD               = data.terraform_remote_state.db.outputs.rds_master_password
      DB_SSL                    = "true"
      SECURITY_JWT_SECRET_KEY   = data.terraform_remote_state.infra.outputs.jwt_secret_base64
      ACCESS_TOKEN_TTL_SECONDS  = var.access_token_ttl_seconds
    }
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }

  tags = local.tags
}

# API Gateway
resource "aws_api_gateway_rest_api" "auth" {
  name        = "${var.env}-lambda-auth-api"
  description = "API for Lambda Auth"
  tags        = local.tags
}

resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.auth.id
  parent_id   = aws_api_gateway_rest_api.auth.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.auth.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.auth.id
  resource_id = aws_api_gateway_method.auth_post.resource_id
  http_method = aws_api_gateway_method.auth_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.auth.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.auth.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "auth" {
  depends_on = [
    aws_api_gateway_integration.lambda
  ]

  rest_api_id = aws_api_gateway_rest_api.auth.id
}

resource "aws_api_gateway_stage" "auth" {
  deployment_id = aws_api_gateway_deployment.auth.id
  rest_api_id   = aws_api_gateway_rest_api.auth.id
  stage_name    = "Prod"
}
