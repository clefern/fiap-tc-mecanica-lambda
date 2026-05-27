output "lambda_function_name" {
  value = aws_lambda_function.auth.function_name
}

output "lambda_arn" {
  value = aws_lambda_function.auth.arn
}

output "api_gateway_url" {
  value = "https://${local.execute_api_host}/${aws_api_gateway_stage.auth.stage_name}/auth"
}

output "api_gateway_host" {
  value = local.execute_api_host
}

output "k8s_cluster_name" {
  description = "Nome do cluster EKS (via remote state infra)"
  value       = data.terraform_remote_state.infra.outputs.cluster_name
}
