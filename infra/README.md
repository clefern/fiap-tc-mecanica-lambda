# Auth Lambda (Terraform)

Deploy da função **CPF → JWT** e do **API Gateway REST** (`POST /Prod/auth`), equivalente ao `template.yaml` SAM, com state separado do cluster e do RDS (mesmo padrão de `fiap-tc-mecanica-infra-db`).

## Pré-requisitos

1. **AWS profile** `fiap-lab` (ou `export AWS_PROFILE=...`).
2. **State S3** — nomes S3 são **globais**; `fiap-tc-lab-tfstate` sem sufixo costuma falhar (`BucketAlreadyExists`). Use bucket **por conta**:
   ```bash
   export AWS_PROFILE=fiap-lab
   ./scripts/bootstrap_tf_lab.sh
   export TF_STATE_BUCKET=fiap-tc-lab-tfstate-<ACCOUNT_ID>   # impresso pelo script
   ```
   O mesmo `TF_STATE_BUCKET` deve ser usado nos stacks **k8s** e **RDS** antes da Lambda.
3. **Cluster** state em `s3://fiap-tc-lab-tfstate/lab/terraform.tfstate` (`infra/environments/lab` no repo k8s).
4. **RDS** state em `s3://fiap-tc-lab-tfstate/lab/db/terraform.tfstate` (`fiap-tc-mecanica-infra-db`).
5. **JWT secret** igual ao Secret Kubernetes `SECURITY_JWT_SECRET_KEY` (Base64 HMAC).
6. Artefato: `npm run package` → `lambda.zip`.

## Layout

```
infra/
├── conf/
│   ├── 0-providers.tf      # AWS provider + terraform block
│   ├── 1-remote-state.tf   # lê state k8s + db
│   ├── 2-lambda-auth.tf    # Lambda + IAM + API Gateway + SG rule no RDS
│   ├── data.tf
│   ├── locals.tf
│   ├── variables.tf
│   └── output.tf           # auth_api_url, auth_execute_api_host
└── environments/
    ├── lab/              # backend S3: lab/lambda/terraform.tfstate
    └── develop/        # backend comentado (state local até configurar S3)
```

## Deploy (lab)

```bash
export AWS_PROFILE=fiap-lab
./scripts/bootstrap_tf_lab.sh
export TF_STATE_BUCKET=fiap-tc-lab-tfstate-<ACCOUNT_ID>   # impresso pelo bootstrap

# 1) VPC/EKS + RDS na AWS (obrigatório — Minikube não grava este state)
./scripts/apply-lab-prerequisites.sh

# 2) Lambda + wire Traefik
export TF_VAR_jwt_secret="$SECURITY_JWT_SECRET_KEY"
./scripts/deploy-auth-lambda.sh lab ../fiap-tc-mecanica-java-original
```

Isso executa: `npm run package` → `terraform apply` → gera `auth-apigw-host.patch.yaml` nos overlays K8s.

## Wire manual (só Traefik)

```bash
cd infra/environments/lab
terraform output -raw auth_execute_api_host
../../scripts/wire-traefik-auth-gateway.sh lab ../fiap-tc-mecanica-java-original
```

## Outputs → Traefik

| Output                  | Uso no K8s                                                               |
| ----------------------- | ------------------------------------------------------------------------ |
| `auth_execute_api_host` | `ExternalName`, `ServersTransport.serverName`, middleware `Host`         |
| `auth_api_url`          | Teste direto: `curl -X POST "$(terraform output -raw auth_api_url)" ...` |

Traefik no cluster expõe `POST /auth` e reescreve para `/Prod/auth` no API Gateway (middlewares em `k8s/base-gateway/` do `java-original`).

## Lab vs develop

- **lab**: usa `LabRole` existente (não cria IAM role — restrição AWS Academy).
- **develop**: cria `aws_iam_role` + policy (logs + VPC ENI), como no exemplo `7-s3-batch-migration.tf`.

## SAM

O `template.yaml` permanece como referência; o deploy recomendado da Fase 3 é este Terraform.
