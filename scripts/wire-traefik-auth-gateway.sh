#!/usr/bin/env bash
# Gera patches Traefik nos overlays K8s a partir do output Terraform da auth Lambda.
#
# Uso:
#   ./scripts/wire-traefik-auth-gateway.sh lab
#   ./scripts/wire-traefik-auth-gateway.sh lab ../fiap-tc-mecanica-java-original
#   ./scripts/wire-traefik-auth-gateway.sh lab ../fiap-tc-mecanica-infra-k8s infra-k8s
#
set -euo pipefail

ENV="${1:?environment required (lab|develop|local)}"
K8S_REPO="${2:-../fiap-tc-mecanica-java-original}"
LAYOUT="${3:-java-original}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${LAMBDA_ROOT}/infra/environments/${ENV}"

if [[ "${ENV}" == "local" ]]; then
  TF_DIR="${LAMBDA_ROOT}/infra/environments/lab"
fi

if [[ ! -d "${TF_DIR}" ]]; then
  echo "Terraform env not found: ${TF_DIR}" >&2
  exit 1
fi

HOST="$(cd "${TF_DIR}" && terraform output -raw auth_execute_api_host)"
echo "Auth execute-api host: ${HOST}"

write_java_original_gateway() {
  local gw_dir="$1"
  mkdir -p "${gw_dir}"

  cat >"${gw_dir}/auth-apigw-service.patch.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: lambda-auth-external
spec:
  externalName: ${HOST}
EOF

  cat >"${gw_dir}/auth-apigw-transport.patch.yaml" <<EOF
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: apigwtransport
spec:
  serverName: ${HOST}
EOF

  cat >"${gw_dir}/auth-apigw-host-header.patch.yaml" <<EOF
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: apigwhost
spec:
  headers:
    customRequestHeaders:
      Host: ${HOST}
EOF

  echo "Wrote ${gw_dir}/auth-apigw-*.patch.yaml"
}

write_infra_k8s_overlay() {
  local overlay_dir="$1"
  mkdir -p "${overlay_dir}"

  cat >"${overlay_dir}/auth-apigw-service.patch.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: lambda-auth-external
spec:
  externalName: ${HOST}
EOF

  cat >"${overlay_dir}/auth-apigw-transport.patch.yaml" <<EOF
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: lambda-apigw-transport
spec:
  serverName: ${HOST}
EOF

  cat >"${overlay_dir}/auth-apigw-host-header.patch.yaml" <<EOF
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: lambda-apigw-host
spec:
  headers:
    customRequestHeaders:
      Host: ${HOST}
EOF

  rm -f "${overlay_dir}/auth-apigw-host.patch.yaml"
  echo "Wrote ${overlay_dir}/auth-apigw-*.patch.yaml"
}

case "${LAYOUT}" in
  java-original)
    if [[ -d "${K8S_REPO}/k8s/overlays/${ENV}/gateway" ]]; then
      write_java_original_gateway "${K8S_REPO}/k8s/overlays/${ENV}/gateway"
    else
      write_java_original_gateway "${K8S_REPO}/k8s/overlays/${ENV}"
    fi
    ;;
  infra-k8s)
    write_infra_k8s_overlay "${K8S_REPO}/k8s/overlays/${ENV}"
    ;;
  *)
    echo "Unknown layout: ${LAYOUT} (use java-original or infra-k8s)" >&2
    exit 1
    ;;
esac

echo ""
echo "Próximo passo:"
echo "  kubectl apply -k ${K8S_REPO}/k8s/overlays/${ENV}/"
echo "Teste:"
echo "  curl -X POST \"http://\$(minikube ip):30080/auth\" -H 'Content-Type: application/json' -d '{\"cpf\":\"45933904279\"}'"
