# Auth Lambda (CPF → JWT) + API Gateway REST — equivalente ao template.yaml SAM.
# Padrão IAM/Lambda inspirado em events-service-terraform (7-s3-batch-migration.tf).

resource "aws_security_group" "lambda_auth" {
  name        = "${var.env}-mecanica-auth-lambda"
  description = "Egress from auth Lambda to RDS and AWS APIs"
  vpc_id      = data.terraform_remote_state.k8s.outputs.vpc_id

  egress {
    description = "All outbound (RDS, Secrets, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.env}-mecanica-auth-lambda"
  })
}

resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.db.outputs.rds_security_group_id
  source_security_group_id = aws_security_group.lambda_auth.id
  description              = "PostgreSQL from auth Lambda"
}

resource "aws_iam_role" "lambda_auth" {
  count = local.is_lab_env ? 0 : 1
  name  = "${var.env}-mecanica-auth-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_auth" {
  count = local.is_lab_env ? 0 : 1
  name  = "${var.env}-mecanica-auth-lambda"
  role  = aws_iam_role.lambda_auth[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "auth" {
  function_name = "mecanica-auth-${var.env}"
  description   = "CPF → JWT (HS256) — FIAP TC Mecânica auth"
  role          = local.lambda_role_arn
  handler       = "handler.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  timeout       = 10
  memory_size   = 256

  filename         = local.lambda_package_path
  source_code_hash = filebase64sha256(local.lambda_package_path)

  environment {
    variables = {
      NODE_OPTIONS             = "--enable-source-maps"
      DB_HOST                  = data.terraform_remote_state.db.outputs.rds_endpoint
      DB_PORT                  = tostring(data.terraform_remote_state.db.outputs.rds_port)
      DB_NAME                  = data.terraform_remote_state.db.outputs.rds_db_name
      DB_USER                  = data.terraform_remote_state.db.outputs.rds_master_username
      DB_PASSWORD              = data.terraform_remote_state.db.outputs.rds_master_password
      DB_SSL                   = "true"
      SECURITY_JWT_SECRET_KEY  = var.jwt_secret
      ACCESS_TOKEN_TTL_SECONDS = var.access_token_ttl_seconds
    }
  }

  vpc_config {
    subnet_ids         = data.terraform_remote_state.k8s.outputs.subnet_ids
    security_group_ids = [aws_security_group.lambda_auth.id]
  }

  depends_on = [
    aws_iam_role_policy.lambda_auth,
    aws_security_group_rule.rds_from_lambda,
  ]

  tags = local.tags
}

resource "aws_api_gateway_rest_api" "auth" {
  name        = "${var.env}-mecanica-auth"
  description = "POST /auth → Lambda CPF→JWT"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.tags
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

resource "aws_api_gateway_integration" "auth_lambda" {
  rest_api_id = aws_api_gateway_rest_api.auth.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.auth.invoke_arn
}

resource "aws_api_gateway_deployment" "auth" {
  rest_api_id = aws_api_gateway_rest_api.auth.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_method.auth_post.id,
      aws_api_gateway_integration.auth_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.auth_lambda]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.auth.id
  rest_api_id   = aws_api_gateway_rest_api.auth.id
  stage_name    = "Prod"

  tags = local.tags
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.auth.execution_arn}/*/*"
}
