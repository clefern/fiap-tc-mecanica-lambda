# fiap-tc-mecanica-lambda

> AWS Lambda — Autenticação CPF → JWT — **Mecânica API · FIAP Tech Challenge Fase 3 · Grupo 14SOAT**

Function Serverless que recebe o **CPF do cliente**, consulta sua existência e status no RDS PostgreSQL, e devolve um **JWT HS256** válido para consumo das APIs protegidas da aplicação. Parte do split da Fase 3 em 4 repos:

| Repo | Conteúdo |
|---|---|
| [`fiap-tc-mecanica-app`](https://github.com/clefern/fiap-tc-mecanica-app) | Aplicação principal (Java 21 + Spring Boot) |
| [`fiap-tc-mecanica-infra-k8s`](https://github.com/clefern/fiap-tc-mecanica-infra-k8s) | Terraform do cluster + Kustomize manifests |
| [`fiap-tc-mecanica-infra-db`](https://github.com/clefern/fiap-tc-mecanica-infra-db) | Terraform do RDS PostgreSQL |
| **`fiap-tc-mecanica-lambda`** | **Este repo** — Lambda CPF → JWT |

---

## Estado atual

> Handler completo: validação de CPF, consulta `clientes` + `users` no RDS, cliente ativo (`account_status`), JWT HS256 **compatível com o Spring** (`sub` = email, secret **Base64** como no `JwtService`). Pendências típicas de deploy: primeira esteira `sam deploy`, VPC (subnets + SG liberando 5432 para a Lambda).

## Como funciona

```
Cliente  →  POST /auth { cpf }  →  API Gateway  →  Lambda
                                                     │
                                                     │ valida CPF (DV + tamanho + dígitos iguais)
                                                     │
                                                     ▼
                                            RDS PostgreSQL
                                            (lookup por documento)
                                                     │
                                                     ▼
                                            jwt.sign(HS256, Buffer.from(SECURITY_JWT_SECRET_KEY, "base64"))
                                                     │
                                                     ▼
                            { access_token, token_type: "Bearer", expires_in, cliente }
```

A app Spring Boot (`fiap-tc-mecanica-app`) valida esse JWT via o `JwtAuthenticationFilter` / `JwtService`: a chave em `SECURITY_JWT_SECRET_KEY` é **Base64 dos bytes HMAC** (igual `Decoders.BASE64.decode` no Java), e o **subject** do token deve ser o **e-mail** do usuário (mesmo contrato do login interno).

## Tecnologias

- **Runtime**: Node.js 20 (ARM64)
- **Linguagem**: TypeScript 5.6 (strict mode)
- **Lib JWT**: `jsonwebtoken` 9.x — HS256, mesma estratégia que o `JwtService` do app
- **DB driver**: `pg` 8.x — conexão direta ao RDS via VPC
- **Testes**: Vitest 2.x
- **IaC**: AWS SAM (`template.yaml`)
- **CI**: GitHub Actions (`build + lint + test` em push/PR)

## Estrutura

```
.
├── src/
│   ├── handler.ts         # APIGatewayProxyHandler — fluxo completo CPF → JWT
│   ├── cpf.ts             # Validação CPF (DV módulo 11, espelha DocumentoFactory do app)
│   ├── jwt.ts             # Emissão JWT HS256 (mesma secret do app)
│   └── repository.ts      # SELECT cliente WHERE documento = $1 no RDS
├── tests/
│   ├── cpf.test.ts        # 6 casos de borda
│   └── handler.test.ts    # Mock do repository — cobre 400/403/404/200
├── template.yaml          # AWS SAM — Function + API Gateway + VPC config
├── package.json           # Node 20, Vitest, deps mínimas
├── tsconfig.json          # strict + ES2022 + commonjs
├── .github/workflows/ci.yml
├── .env.example
└── .gitignore
```

## Pré-requisitos

- Node.js >= 20
- AWS CLI configurado
- AWS SAM CLI (`brew install aws-sam-cli`)
- Acesso à VPC do RDS (security group permitindo 5432 do CIDR da Lambda)

## Setup local

```bash
npm install
cp .env.example .env   # preencher com endpoint RDS e JWT secret
npm test               # vitest run
npm run build          # tsc → dist/
```

### Smoke local

```bash
sam build
sam local invoke AuthFunction --event events/auth-cliente-ativo.json
```

## Deploy

### Terraform (recomendado — Fase 3)

State separado em `infra/` (mesmo padrão de `fiap-tc-mecanica-infra-db`). Pré-requisitos: cluster + RDS já aplicados.

```bash
export TF_VAR_jwt_secret="$SECURITY_JWT_SECRET_KEY"   # mesma secret do k8s / Spring Boot
./scripts/deploy-auth-lambda.sh lab ../fiap-tc-mecanica-java-original
```

Outputs: `auth_api_url`, `auth_execute_api_host` (wire automático nos patches Traefik). Ver [`infra/README.md`](infra/README.md).

### SAM (alternativo)

```bash
sam build
sam deploy --guided \
  --parameter-overrides \
    Environment=develop \
    DbHost=$(cd ../fiap-tc-mecanica-infra-db/infra/environments/develop && terraform output -raw rds_endpoint) \
    DbPassword=$(cd ../fiap-tc-mecanica-infra-db/infra/environments/develop && terraform output -raw rds_master_password) \
    JwtSecret=$SECURITY_JWT_SECRET_KEY
```

Após deploy, o endpoint público fica em:

```
https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/auth
```

## Contrato da API

### `POST /auth`

Request:
```json
{ "cpf": "529.982.247-25" }
```

Response `200`:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiJ9....",
  "token_type": "Bearer",
  "expires_in": 3600,
  "cliente": {
    "id": "11111111-1111-1111-1111-111111111111",
    "nome": "Fulano",
    "email": "fulano@mecanica.com"
  }
}
```

Erros:

| Código | HTTP | Causa |
|---|---|---|
| `AUTH-400-01` | 400 | JSON malformado |
| `AUTH-400-02` | 400 | Campo `cpf` ausente |
| `AUTH-400-03` | 400 | CPF inválido (DV/tamanho) |
| `AUTH-404-01` | 404 | Cliente não encontrado |
| `AUTH-403-01` | 403 | Cliente inativo |
| `AUTH-503-01` | 503 | Falha de conexão com RDS |

## Convenção de branches

> ⚠️ Branch protection nativa não está ativa (plano free + repo privado). Convenção do time:
> - **`main`**: apenas via PR aprovado, sem push direto
> - **`develop`**: integração contínua, base dos PRs
> - **Feature branches**: `feat/<scope>` ou `feature/<scope>`

## Roadmap

1. Empacotamento + primeiro deploy SAM (`sam deploy --guided`)
2. (Opcional) Host único no DNS: CNAME para o NLB do NGINX (API) + URL separada do API Gateway (`execute-api`) para `POST /auth`, ou uso de **Traefik** / compose local como em `fiap-tc-mecanica-java-original`
3. RFC-003 — Estratégia de auth CPF (registrar no repo `fiap-tc-mecanica-app/docs/RFCs/`)
4. Diagrama de sequência (cliente → API Gateway → Lambda → RDS → JWT) no C4 da app
5. Métricas Lambda (CloudWatch → APM Datadog/New Relic, decisão pendente em OBS-001)

## Licença

Acadêmico — FIAP Tech Challenge 13SOAT.
