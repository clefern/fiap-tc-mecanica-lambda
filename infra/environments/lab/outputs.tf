output "lambda_function_name" {
  value = module.lambda_auth.lambda_function_name
}

output "api_gateway_url" {
  value = module.lambda_auth.api_gateway_url
}

output "api_gateway_host" {
  value = module.lambda_auth.api_gateway_host
}

output "k8s_cluster_name" {
  value = module.lambda_auth.k8s_cluster_name
}
