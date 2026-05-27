variable "profile" {
  description = "AWS profile (alinhado ao backend S3; em CI use null + credenciais de ambiente)"
  type        = string
  default     = null
  nullable    = true
}

variable "remote_state_bucket" {
  description = "Nome do bucket do estado remoto"
  type        = string
  default     = "fiap-tc-lab-tfstate"
}

variable "remote_state_infra_key" {
  description = "Chave completa do estado da infra base (ex: lab/infra/terraform.tfstate)"
  type        = string
  default     = "lab/infra/terraform.tfstate"
}

variable "remote_state_db_key" {
  description = "Chave completa do estado do banco de dados (ex: lab/db/terraform.tfstate)"
  type        = string
  default     = "lab/db/terraform.tfstate"
}

variable "remote_state_region" {
  description = "Região do bucket de estado remoto"
  type        = string
  default     = "us-east-1"
}
