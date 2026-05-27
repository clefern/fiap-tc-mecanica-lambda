#!/bin/bash
set -euox pipefail

# ---------------------------------------------------------------------------
# deploy.sh — Deploy da Lambda Auth e Patch no EKS
# Variáveis: ENVIRONMENT, AWS_REGION, BUCKET_NAME
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🚀 Iniciando deploy da Lambda Auth no ambiente: '${ENVIRONMENT}'"

# 1. Verificar artefatos de build (ZIP) no ROOT_DIR
if [ ! -f "${ROOT_DIR}/lambda.zip" ]; then
  echo "❌ Erro: Arquivo '${ROOT_DIR}/lambda.zip' não encontrado."
  echo "A fase de build deve gerar o ZIP antes do deploy."
  exit 1
fi

echo "📦 Artefato lambda.zip encontrado. Prosseguindo..."

# 2. Garantir Bucket S3 para o estado
echo "🔍 Verificando bucket S3: $BUCKET_NAME..."
if timeout 10 aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "✅ Bucket $BUCKET_NAME já existe."
else
  echo "🪣 Criando bucket $BUCKET_NAME..."
  aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$AWS_REGION"
fi

# 3. Deploy da Infra Lambda (Terraform)
echo "🏗️ Aplicando Terraform da Lambda..."

terraform init -input=false \
  -backend-config="bucket=${BUCKET_NAME}" \
  -backend-config="key=${ENVIRONMENT}/${DOMAIN}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"

terraform plan -out=tfplan \
  -var="remote_state_bucket=${BUCKET_NAME}" \
  -var="remote_state_infra_key=${ENVIRONMENT}/${BUCKET_STATE_INFRA_KEY}/terraform.tfstate" \
  -var="remote_state_db_key=${ENVIRONMENT}/${BUCKET_STATE_DB_KEY}/terraform.tfstate" \
  -var="remote_state_region=${AWS_REGION}"

terraform apply -input=false -auto-approve tfplan

# 4. Atualizar código da Lambda
FUNCTION_NAME="$(terraform output -raw lambda_function_name)"
aws lambda update-function-code \
  --function-name "${FUNCTION_NAME}" \
  --zip-file "fileb://${ROOT_DIR}/lambda.zip" \
  --region "${AWS_REGION}"

# 5. Obter host do API Gateway
LAMBDA_AUTH_HOST="$(terraform output -raw api_gateway_host)"
echo "🌐 API Gateway Host detectado: ${LAMBDA_AUTH_HOST}"

# 6. SURGICAL PATCH: Conectar a Lambda ao Ingress do EKS
echo "☸️ Patching Ingress resources no EKS..."
CLUSTER_NAME=$(terraform output -raw k8s_cluster_name 2>/dev/null)
aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${CLUSTER_NAME}"

# Patch no Service ExternalName
kubectl patch service lambda-auth-external -n ${NAMESPACE} \
  -p '{"spec":{"externalName":"'${LAMBDA_AUTH_HOST}'"}}'

# Patch no ServersTransport do Traefik (HTTPS para APIGW)
kubectl patch serverstransport mecanica-lambda-apigw-transport -n ${NAMESPACE} --type=merge \
  -p '{"spec":{"serverName":"'${LAMBDA_AUTH_HOST}'"}}'

# Patch no Middleware de Host do Traefik
kubectl patch middleware lambda-apigw-host -n ${NAMESPACE} --type=merge \
  -p '{"spec":{"headers":{"customRequestHeaders":{"Host":"'${LAMBDA_AUTH_HOST}'"}}}}'

echo "✅ Deploy e Conexão da Lambda Auth concluídos com sucesso!"
