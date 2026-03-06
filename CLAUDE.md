# CLAUDE.md - Convencoes do Projeto ToggleMaster

## Visao Geral

Plataforma de Feature Flags com 5 microsservicos. Tech Challenge Fase 3 - FIAP.
Monorepo com 4 camadas: `terraform/`, `microservices/`, `gitops/`, `scripts/`.

**Repo:** github.com/rivachef/TC3-ToggleMaster

---

## Arquitetura

### Microsservicos

| Servico | Linguagem | Porta | Funcao |
|---------|-----------|-------|--------|
| auth-service | Go 1.21 | 8001 | Gerenciamento de API keys |
| flag-service | Python 3.12/Flask | 8002 | CRUD de feature flags |
| targeting-service | Python 3.12/Flask | 8003 | Regras de segmentacao |
| evaluation-service | Go 1.21 | 8004 | Avaliacao de flags em tempo real |
| analytics-service | Python 3.12/Flask | 8005 | Analytics via SQS/DynamoDB |

### Infraestrutura AWS (39 recursos via Terraform)

- EKS (1 cluster, 2 nodes t3.medium) com LabRole
- 3x RDS PostgreSQL (auth-db, flag-db, targeting-db)
- 1x ElastiCache Redis
- 1x SQS Queue
- 1x DynamoDB (ToggleMasterAnalytics)
- 5x ECR (tag IMMUTABLE)
- VPC com subnets publicas/privadas, NAT Gateway

---

## Convencoes Criticas

### AWS Academy

- **SEM criar IAM Roles/Policies** - usar LabRole existente via `lab_role_arn`
- Credenciais temporarias (4h) - renovar com `./scripts/update-aws-credentials.sh`
- Scripts suportam credenciais via `export` E via `aws configure`
- Region: sempre `us-east-1`

### Secrets Kubernetes

- Secrets **NUNCA** no git - estao no `.gitignore` (`gitops/**/secret.yaml`)
- Usar `stringData` (texto puro), NAO `data` (base64) - K8s converte automaticamente
- Gerar via `./scripts/generate-secrets.sh` (le terraform output + AWS creds + tfvars)
- Templates de referencia: `secret.yaml.example` em cada servico
- DB init jobs (auth, flag, targeting) usam secrets em `db/secret.yaml`

### Auth Service - API Key Generation

- Endpoint: `POST /admin/keys`
- Header: `Authorization: Bearer $MASTER_KEY` (NAO `X-Master-Key`)
- Body: `{"name": "evaluation-service"}` (NAO `description`)
- Response field: `key`
- MASTER_KEY gerada por `openssl rand -hex 32` no generate-secrets.sh

### Workflows CI/CD (.github/workflows/)

- 5 workflows independentes, um por microsservico
- `permissions: contents: write` APENAS no job `update-gitops` (menor privilegio)
- NAO colocar permissions no nivel do workflow global
- Trivy filesystem scan: `exit-code: '1'` (bloqueante - DevSecOps rigoroso)
- Trivy container scan: `exit-code: '0'` (reporta mas nao bloqueia)
- gosec pinado em `v2.20.0` (compativel com Go 1.21) + `continue-on-error: true`
- golangci-lint pinado em `v1.61`
- Docker image tag: short SHA do commit (`cut -c1-7`)
- Job `update-gitops` faz `sed` + commit automatico via `github-actions[bot]`

### ArgoCD

- 6 Applications: 5 servicos + 1 shared (namespace + ingress)
- Sync Policy: automatico com `prune: true` e `selfHeal: true`
- `sourceRepos` restrito ao repo especifico (nao wildcard `*`)
- Namespace: `argocd`
- Exposto via LoadBalancer

### Terraform

- Backend remoto: S3 (`togglemaster-terraform-state`) + DynamoDB lock (`togglemaster-terraform-lock`)
- Modulos: `networking`, `eks`, `databases`, `messaging`, `ecr`
- ECR: `image_tag_mutability = "IMMUTABLE"`
- Se `terraform init` falhar com digest stale, deletar item no DynamoDB e `init -reconfigure`

---

## Compatibilidade macOS

- **NAO usar `sed` com `\s`** - BSD sed do macOS nao suporta. Usar `python3` para parsing:
  ```bash
  # ERRADO (falha no macOS):
  sed 's/.*=\s*"\(.*\)"/\1/'

  # CORRETO (funciona em macOS e Linux):
  python3 -c "import sys; print(sys.stdin.read().split('\"')[1])"
  ```
- Docker build: usar `--platform linux/amd64` em Apple Silicon (M1/M2/M3)

---

## Scripts de Automacao (scripts/)

| Script | Funcao | Chamado por |
|--------|--------|-------------|
| `setup-full.sh` | Master - orquestra 8 passos do setup | Usuario |
| `generate-secrets.sh` | Gera 8 secret.yaml do terraform output | setup-full.sh |
| `apply-secrets.sh` | kubectl apply dos 8 secrets | setup-full.sh |
| `generate-api-key.sh` | Gera SERVICE_API_KEY via auth-service | setup-full.sh |
| `update-aws-credentials.sh` | Renova AWS creds nos secrets (4h) | Usuario |

### Ordem de execucao no setup-full.sh:

1. Verificacoes (AWS creds, kubectl)
2. generate-secrets.sh
3. Instalar ArgoCD
4. apply-secrets.sh
5. Docker build/push ECR (skip se imagens ja existem)
6. ArgoCD Applications
7. NGINX Ingress
8. Aguardar pods
9. generate-api-key.sh

**IMPORTANTE:** Docker build ANTES de ArgoCD Applications, senao pods ficam em ImagePullBackOff.

---

## Estrutura GitOps

```
gitops/
├── namespace.yaml
├── ingress.yaml
├── auth-service/
│   ├── deployment.yaml      # ConfigMap + Deployment (image tag atualizada pelo CI)
│   ├── service.yaml
│   ├── hpa.yaml
│   ├── secret.yaml          # GITIGNORED - gerado por generate-secrets.sh
│   ├── secret.yaml.example  # Template com placeholders
│   └── db/
│       ├── job.yaml          # DB init job
│       ├── configmap.yaml    # SQL init script
│       └── secret.yaml       # GITIGNORED - DB credentials
├── flag-service/             # Mesma estrutura (sem hpa)
├── targeting-service/        # Mesma estrutura (sem hpa)
├── evaluation-service/       # Sem db/, com hpa.yaml
└── analytics-service/        # Sem db/, sem hpa
```

---

## Namespace Kubernetes

Tudo roda no namespace `togglemaster`. Exceto ArgoCD (`argocd`) e Ingress (`ingress-nginx`).

## Pods Esperados

- 10 pods Running (2 replicas x 5 servicos)
- 3 jobs Completed (auth-db-init, flag-db-init, targeting-db-init)

---

## GitHub Secrets Necessarios

| Secret | Valor |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Da sessao AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Da sessao AWS Academy |
| `AWS_SESSION_TOKEN` | Da sessao AWS Academy |
| `ECR_REGISTRY` | `<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com` |

Atualizar AWS creds a cada nova sessao (4h).
