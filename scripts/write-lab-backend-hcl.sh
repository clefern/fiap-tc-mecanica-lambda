#!/usr/bin/env bash
# Escreve backend.hcl (gitignored) para k8s, RDS e Lambda com o mesmo bucket S3.
set -euo pipefail

BUCKET="${1:?bucket name required}"
REGION="${2:-us-east-1}"
PROFILE="${3:-${AWS_PROFILE:-fiap-lab}}"
DYNAMO_TABLE="${4:-terraform-lock-table}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TC_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

write_backend_hcl() {
  local dir="$1"
  local key="$2"
  mkdir -p "${dir}"
  cat >"${dir}/backend.hcl" <<EOF
# Gerado por write-lab-backend-hcl.sh — não commitar.
bucket         = "${BUCKET}"
key            = "${key}"
region         = "${REGION}"
profile        = "${PROFILE}"
dynamodb_table = "${DYNAMO_TABLE}"
EOF
  echo "  ${dir}/backend.hcl  (key=${key})"
}

echo "Writing backend.hcl files for bucket=${BUCKET}"
write_backend_hcl "${TC_ROOT}/fiap-tc-mecanica-java-original/infra/environments/lab" "lab/terraform.tfstate"
write_backend_hcl "${TC_ROOT}/fiap-tc-mecanica-infra-db/infra/environments/lab" "lab/db/terraform.tfstate"
write_backend_hcl "${TC_ROOT}/fiap-tc-mecanica-lambda/infra/environments/lab" "lab/lambda/terraform.tfstate"
echo "Done."
