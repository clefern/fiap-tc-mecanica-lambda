#!/usr/bin/env bash
# Aplica infra AWS lab necessária antes da auth Lambda: EKS/VPC (k8s) → RDS (db).
#
# Minikube cobre só o cluster local; a Lambda roda na AWS e precisa de VPC + RDS no lab.
#
# Uso:
#   export AWS_PROFILE=fiap-lab
#   ./scripts/bootstrap_tf_lab.sh
#   export TF_STATE_BUCKET=fiap-tc-lab-tfstate-<ACCOUNT_ID>
#   ./scripts/apply-lab-prerequisites.sh
#   ./scripts/apply-lab-prerequisites.sh --yes   # skip terraform confirmation prompts
#
set -euo pipefail

AUTO_APPROVE=()
if [[ "${1:-}" == "--yes" || "${TF_AUTO_APPROVE:-}" == "1" ]]; then
  AUTO_APPROVE=(-auto-approve)
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TC_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LAB_PROFILE="${AWS_PROFILE:-fiap-lab}"
LAB_REGION="${AWS_REGION:-us-east-1}"

resolve_bucket() {
  if [[ -n "${TF_STATE_BUCKET:-}" ]]; then
    echo "${TF_STATE_BUCKET}"
    return
  fi
  local backend="${SCRIPT_DIR}/../infra/environments/lab/backend.hcl"
  if [[ -f "${backend}" ]]; then
    grep -E '^bucket' "${backend}" | sed 's/.*=\s*"\(.*\)".*/\1/'
    return
  fi
  aws sts get-caller-identity --query Account --output text --profile "${LAB_PROFILE}" \
    | awk '{print "fiap-tc-lab-tfstate-" $1}'
}

BUCKET="$(resolve_bucket)"
export TF_STATE_BUCKET="${BUCKET}"

echo "==> backend.hcl for all lab stacks (bucket=${BUCKET})"
"${SCRIPT_DIR}/write-lab-backend-hcl.sh" "${BUCKET}" "${LAB_REGION}" "${LAB_PROFILE}"

K8S_DIR="${TC_ROOT}/fiap-tc-mecanica-java-original/infra/environments/lab"
DB_DIR="${TC_ROOT}/fiap-tc-mecanica-infra-db/infra/environments/lab"

if [[ ! -d "${K8S_DIR}" ]]; then
  K8S_DIR="${TC_ROOT}/fiap-tc-mecanica-infra-k8s/infra/environments/lab"
fi

echo ""
echo "==> [1/2] Kubernetes / VPC / EKS (lab)"
echo "    ${K8S_DIR}"
(cd "${K8S_DIR}" && terraform init -input=false -backend-config=backend.hcl && terraform apply \
  "${AUTO_APPROVE[@]}" -var="enable_newrelic_observability=false")

echo ""
echo "==> [2/2] RDS PostgreSQL (lab)"
echo "    ${DB_DIR}"
export TF_VAR_tf_state_bucket="${BUCKET}"
(cd "${DB_DIR}" && terraform init -input=false -backend-config=backend.hcl && terraform apply \
  "${AUTO_APPROVE[@]}" -var="tf_state_bucket=${BUCKET}")

echo ""
echo "Prerequisites ready. Deploy Lambda:"
echo "  export TF_VAR_jwt_secret='...'"
echo "  ./scripts/deploy-auth-lambda.sh lab ../fiap-tc-mecanica-java-original"
