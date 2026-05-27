#!/bin/bash
set -euox pipefail

echo "🗑️ Iniciando Cleanup da Lambda Auth no ambiente: ${ENVIRONMENT}"

# 0. Garantir Bucket S3 para o estado (se não existir, não há estado para limpar)
echo "🔍 Verificando bucket S3: ${BUCKET_NAME}..."
if ! timeout 10 aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "ℹ️ Bucket ${BUCKET_NAME} não existe. Nada para limpar."
  exit 0
fi

# 1. Terraform Init
terraform init -input=false \
  -backend-config="bucket=${BUCKET_NAME}" \
  -backend-config="key=${ENVIRONMENT}/${DOMAIN}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"

# 2. Terraform Destroy
terraform destroy -auto-approve \
  -var="remote_state_bucket=${BUCKET_NAME}" \
  -var="remote_state_infra_key=${ENVIRONMENT}/${BUCKET_STATE_INFRA_KEY}/terraform.tfstate" \
  -var="remote_state_db_key=${ENVIRONMENT}/${BUCKET_STATE_DB_KEY}/terraform.tfstate" \
  -var="remote_state_region=${AWS_REGION}"

# 3. Limpeza do Estado no S3 (Padrão dos outros forks)
echo "🔍 Removendo arquivos de estado do S3..."
STATE_KEY="${ENVIRONMENT}/${DOMAIN}/terraform.tfstate"
aws s3 rm "s3://${BUCKET_NAME}/${STATE_KEY}" || true

echo "✅ Cleanup da Lambda Auth finalizado!"
