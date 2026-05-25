#!/usr/bin/env bash
# Build + deploy auth Lambda (Terraform) + wire Traefik nos overlays K8s.
#
# Uso:
#   export AWS_PROFILE=fiap-lab
#   export TF_VAR_jwt_secret="$SECURITY_JWT_SECRET_KEY"
#   ./scripts/bootstrap_tf_lab.sh                    # cria bucket único por conta
#   export TF_STATE_BUCKET=...                     # impresso pelo bootstrap
#   ./scripts/deploy-auth-lambda.sh lab
#
set -euo pipefail

ENV="${1:?environment required (lab|develop)}"
K8S_REPO="${2:-../fiap-tc-mecanica-java-original}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LAB_PROFILE="${AWS_PROFILE:-fiap-lab}"
LAB_REGION="${AWS_REGION:-us-east-1}"
LAB_BACKEND_HCL="${LAMBDA_ROOT}/infra/environments/lab/backend.hcl"

resolve_lab_bucket() {
  if [[ -n "${TF_STATE_BUCKET:-}" ]]; then
    echo "${TF_STATE_BUCKET}"
    return
  fi
  if [[ -f "${LAB_BACKEND_HCL}" ]]; then
    grep -E '^bucket' "${LAB_BACKEND_HCL}" | sed 's/.*=\s*"\(.*\)".*/\1/'
    return
  fi
  aws sts get-caller-identity --query Account --output text --profile "${LAB_PROFILE}" \
    | awk '{print "fiap-tc-lab-tfstate-" $1}'
}

if [[ -z "${TF_VAR_jwt_secret:-}" ]]; then
  echo "Defina TF_VAR_jwt_secret (mesmo valor de SECURITY_JWT_SECRET_KEY no cluster)." >&2
  exit 1
fi

ensure_lab_backend() {
  LAB_BUCKET="$(resolve_lab_bucket)"
  export TF_STATE_BUCKET="${LAB_BUCKET}"
  export TF_VAR_tf_state_bucket="${LAB_BUCKET}"

  if aws s3api head-bucket --bucket "${LAB_BUCKET}" --profile "${LAB_PROFILE}" 2>/dev/null; then
    return 0
  fi
  echo "==> S3 backend ${LAB_BUCKET} not found — running bootstrap_tf_lab.sh"
  "${SCRIPT_DIR}/bootstrap_tf_lab.sh" "${LAB_BUCKET}" "${LAB_REGION}" "${LAB_PROFILE}"
  export TF_STATE_BUCKET="${LAB_BUCKET}"
  export TF_VAR_tf_state_bucket="${LAB_BUCKET}"
}

preflight_remote_state() {
  local key="$1"
  local label="$2"
  if ! aws s3api head-object \
    --bucket "${TF_STATE_BUCKET}" \
    --key "${key}" \
    --profile "${LAB_PROFILE}" \
    --region "${LAB_REGION}" >/dev/null 2>&1; then
    echo "ERROR: Missing remote state for ${label}: s3://${TF_STATE_BUCKET}/${key}" >&2
    echo "" >&2
    echo "Lambda needs AWS VPC (k8s) + RDS in lab. Minikube alone does not create this state." >&2
    echo "Run prerequisites first:" >&2
    echo "  export TF_STATE_BUCKET=${TF_STATE_BUCKET}" >&2
    echo "  ./scripts/apply-lab-prerequisites.sh" >&2
    if [[ -f "${K8S_REPO}/infra/environments/lab/terraform.tfstate" ]]; then
      echo "" >&2
      echo "Hint: local terraform.tfstate found — migrate to S3 on init:" >&2
      echo "  cd ${K8S_REPO}/infra/environments/lab && terraform init -backend-config=backend.hcl -migrate-state" >&2
    fi
    echo "" >&2
    echo "Then deploy Lambda again:" >&2
    echo "  ./scripts/deploy-auth-lambda.sh lab ${K8S_REPO}" >&2
    exit 1
  fi
}

if [[ "${ENV}" == "lab" ]]; then
  ensure_lab_backend
  preflight_remote_state "lab/terraform.tfstate" "EKS/k8s"
  preflight_remote_state "lab/db/terraform.tfstate" "RDS"
fi

echo "==> npm run package"
(cd "${LAMBDA_ROOT}" && npm ci && npm run package)

export TF_VAR_lambda_package_path="${LAMBDA_ROOT}/lambda.zip"

echo "==> terraform init + apply (${ENV})"
TF_ENV_DIR="${LAMBDA_ROOT}/infra/environments/${ENV}"
if [[ "${ENV}" == "lab" ]]; then
  if [[ ! -f "${LAB_BACKEND_HCL}" ]]; then
    echo "ERROR: ${LAB_BACKEND_HCL} missing. Run ./scripts/bootstrap_tf_lab.sh first." >&2
    exit 1
  fi
  (cd "${TF_ENV_DIR}" && terraform init -input=false -backend-config=backend.hcl && terraform apply)
else
  (cd "${TF_ENV_DIR}" && terraform init -input=false && terraform apply)
fi

echo "==> wire Traefik gateway patches"
"${SCRIPT_DIR}/wire-traefik-auth-gateway.sh" "${ENV}" "${K8S_REPO}" java-original

if [[ -d "../fiap-tc-mecanica-infra-k8s/k8s" ]]; then
  "${SCRIPT_DIR}/wire-traefik-auth-gateway.sh" "${ENV}" "../fiap-tc-mecanica-infra-k8s" infra-k8s
fi

echo ""
echo "Auth API URL: $(cd "${TF_ENV_DIR}" && terraform output -raw auth_api_url)"
