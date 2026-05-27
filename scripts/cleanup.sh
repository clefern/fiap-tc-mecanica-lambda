#!/bin/bash
set -euox pipefail

ENVIRONMENT=${1:-lab}
AWS_REGION=${2:-us-east-1}
BUCKET_NAME="fiap-tc-lab-tfstate"
DOMAIN="lambda"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${ROOT_DIR}/infra/environments/${ENVIRONMENT}"

echo "🗑️ Iniciando Cleanup da Lambda Auth no ambiente: ${ENVIRONMENT}"

cd "${INFRA_DIR}"

# 1. Terraform Init
terraform init -input=false \
  -backend-config="bucket=${BUCKET_NAME}" \
  -backend-config="key=${ENVIRONMENT}/${DOMAIN}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"

# 2. Terraform Destroy
terraform destroy -auto-approve

# 3. Limpeza do Estado no S3 (Padrão dos outros forks)
echo "🔍 Removendo arquivos de estado do S3..."
STATE_KEY="${ENVIRONMENT}/${DOMAIN}/terraform.tfstate"
aws s3 rm "s3://${BUCKET_NAME}/${STATE_KEY}" || true

echo "✅ Cleanup da Lambda Auth finalizado!"
