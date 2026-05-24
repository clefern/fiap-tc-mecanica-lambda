output "auth_api_url" {
  description = "Public URL for POST /auth (same shape as SAM AuthApiUrl output)"
  value       = "https://${local.execute_api_host}/${aws_api_gateway_stage.prod.stage_name}/auth"
}

output "auth_execute_api_host" {
  description = "API Gateway hostname for Traefik ExternalName + Host header + TLS SNI"
  value       = local.execute_api_host
}

output "auth_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.auth.arn
}

output "auth_function_name" {
  value = aws_lambda_function.auth.function_name
}

output "auth_api_gateway_id" {
  value = aws_api_gateway_rest_api.auth.id
}

output "auth_lambda_security_group_id" {
  value = aws_security_group.lambda_auth.id
}
