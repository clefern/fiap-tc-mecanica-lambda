#!/usr/bin/env bash
# Cria bucket S3 + tabela DynamoDB para Terraform state (lab AWS Academy).
#
# Nomes S3 são globais — fiap-tc-lab-tfstate costuma estar tomado por outra conta.
# Por padrão usamos fiap-tc-lab-tfstate-<ACCOUNT_ID> (único por conta AWS Academy).
#
# Uso:
#   export AWS_PROFILE=fiap-lab
#   ./scripts/bootstrap_tf_lab.sh
#   ./scripts/bootstrap_tf_lab.sh my-custom-bucket-name
#
set -euo pipefail

REGION="${2:-us-east-1}"
PROFILE="${3:-${AWS_PROFILE:-fiap-lab}}"
DYNAMO_TABLE="${4:-terraform-lock-table}"

AWS=(aws --profile "${PROFILE}" --region "${REGION}")

resolve_bucket_name() {
  if [[ -n "${1:-}" ]]; then
    echo "$1"
    return
  fi
  if [[ -n "${TF_STATE_BUCKET:-}" ]]; then
    echo "${TF_STATE_BUCKET}"
    return
  fi
  local account_id
  account_id="$("${AWS[@]}" sts get-caller-identity --query Account --output text)"
  echo "fiap-tc-lab-tfstate-${account_id}"
}

BUCKET_NAME="$(resolve_bucket_name "${1:-}")"

echo "Bootstrap Terraform state: bucket=${BUCKET_NAME} profile=${PROFILE}"

create_bucket() {
  echo "Creating bucket ${BUCKET_NAME}..."
  if ! "${AWS[@]}" s3 mb "s3://${BUCKET_NAME}" 2>&1; then
    echo "" >&2
    echo "ERROR: Could not create s3://${BUCKET_NAME}" >&2
    echo "If you see BucketAlreadyExists, the name is taken globally — pick another:" >&2
    echo "  export TF_STATE_BUCKET=fiap-tc-lab-tfstate-\$(aws sts get-caller-identity --query Account --output text)" >&2
    echo "  ./scripts/bootstrap_tf_lab.sh \"\${TF_STATE_BUCKET}\"" >&2
    exit 1
  fi
  "${AWS[@]}" s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
  echo "Bucket created."
}

if "${AWS[@]}" s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "Bucket ${BUCKET_NAME} already exists in this account."
else
  create_bucket
fi

if "${AWS[@]}" dynamodb describe-table --table-name "${DYNAMO_TABLE}" >/dev/null 2>&1; then
  echo "DynamoDB table ${DYNAMO_TABLE} already exists."
else
  echo "Creating DynamoDB lock table ${DYNAMO_TABLE}..."
  "${AWS[@]}" dynamodb create-table \
    --table-name "${DYNAMO_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST >/dev/null
  "${AWS[@]}" dynamodb wait table-exists --table-name "${DYNAMO_TABLE}"
  echo "Lock table ready."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_HCL="${SCRIPT_DIR}/../infra/environments/lab/backend.hcl"
mkdir -p "$(dirname "${BACKEND_HCL}")"
cat >"${BACKEND_HCL}" <<EOF
# Gerado por bootstrap_tf_lab.sh — não commitar (gitignored).
bucket         = "${BUCKET_NAME}"
key            = "lab/lambda/terraform.tfstate"
region         = "${REGION}"
profile        = "${PROFILE}"
dynamodb_table = "${DYNAMO_TABLE}"
EOF

if [[ -x "${SCRIPT_DIR}/write-lab-backend-hcl.sh" ]]; then
  "${SCRIPT_DIR}/write-lab-backend-hcl.sh" "${BUCKET_NAME}" "${REGION}" "${PROFILE}" "${DYNAMO_TABLE}"
fi

echo ""
echo "Terraform state backend ready."
echo "  bucket: s3://${BUCKET_NAME}"
echo ""
echo "Use o MESMO bucket nos stacks k8s e RDS:"
echo "  export TF_STATE_BUCKET=${BUCKET_NAME}"
echo ""
echo "Lambda backend config: infra/environments/lab/backend.hcl"
