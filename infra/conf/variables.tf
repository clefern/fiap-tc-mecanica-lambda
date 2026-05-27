variable "profile" {
  description = "AWS profile to use (leave null in CI/CD pipelines)"
  type        = string
  default     = null
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type    = string
  default = "lab"
}

variable "tags" {
  description = "Tags adicionais para os recursos da Lambda"
  type        = map(string)
  default     = {}
}

variable "remote_state_bucket" {
  description = "Nome do bucket do estado remoto (infra + db)"
  type        = string
  default     = "fiap-tc-lab-tfstate"
}

variable "remote_state_infra_key" {
  description = "Chave completa do estado da infra (ex: lab/infra/terraform.tfstate)"
  type        = string
  default     = "lab/infra/terraform.tfstate"
}

variable "remote_state_db_key" {
  description = "Chave completa do estado do banco (ex: lab/db/terraform.tfstate)"
  type        = string
  default     = "lab/db/terraform.tfstate"
}

variable "remote_state_region" {
  description = "Região do bucket de estado remoto"
  type        = string
  default     = "us-east-1"
}

variable "lambda_function_name" {
  type    = string
  default = "mecanica-lambda-auth"
}

variable "lambda_package_path" {
  description = "Caminho absoluto do lambda.zip (opcional)"
  type        = string
  default     = null
  nullable    = true
}

variable "access_token_ttl_seconds" {
  type    = string
  default = "3600"
}
