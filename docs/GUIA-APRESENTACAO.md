# Guia de Apresentacao em Video - ToggleMaster Fase 3

**Duracao maxima:** 20 minutos
**Formato:** Gravacao de tela com narracao

---

## Estrutura Sugerida do Video

### Abertura (1 min)
- [ ] Apresentar os participantes (nome, RM)
- [ ] Explicar brevemente o projeto: "ToggleMaster, plataforma de feature flags com 5 microsservicos"
- [ ] Resumir o objetivo da Fase 3: "Automatizar infra com Terraform, CI/CD com DevSecOps, e GitOps com ArgoCD"

---

### Bloco 1: Infraestrutura como Codigo - Terraform (4-5 min)

**O que mostrar:**

- [ ] Abrir o repositorio no GitHub e mostrar a estrutura geral (`terraform/`, `microservices/`, `gitops/`, `scripts/`)
- [ ] Mostrar a pasta `scripts/` e explicar a automacao (`setup-full.sh` orquestra tudo)
- [ ] Mostrar a organizacao em modulos: `networking`, `eks`, `databases`, `messaging`, `ecr`
- [ ] Abrir `terraform/main.tf` e explicar como os modulos se conectam
- [ ] Mostrar `terraform/backend.tf` - backend remoto no S3 com lock no DynamoDB
- [ ] Mostrar `terraform/variables.tf` - destaque para `lab_role_arn` (AWS Academy)

**Demonstracao ao vivo (ou prints):**

- [ ] Executar `terraform plan` - mostrar os 39 recursos que serao criados
- [ ] Executar `terraform apply` (ou mostrar output do apply ja executado)
- [ ] Mostrar no console AWS os recursos criados:
  - VPC com subnets publicas e privadas
  - Cluster EKS com 2 nodes
  - 3 instancias RDS PostgreSQL
  - ElastiCache Redis
  - Tabela DynamoDB
  - Fila SQS
  - 5 repositorios ECR

**Fala sugerida:**
> "Toda a infraestrutura e provisionada via Terraform com modulos organizados. Usamos backend remoto no S3 para o state file, e a LabRole do AWS Academy e passada como variavel para o EKS."

---

### Bloco 2: Pipeline CI/CD com DevSecOps (6-7 min)

**O que mostrar:**

- [ ] Abrir `.github/workflows/ci-auth-service.yaml` e explicar os 5 jobs sequenciais
- [ ] Destacar que `permissions: contents: write` esta apenas no job `update-gitops` (menor privilegio)
- [ ] Destacar cada estagio:
  1. Build & Unit Test (go build + go test)
  2. Linter (golangci-lint)
  3. Security Scan: Trivy SCA (bloqueante, exit-code: 1) + gosec SAST
  4. Docker Build + Trivy container scan + Push ECR
  5. Update GitOps Manifests (commit automatico)

**Demonstracao 1 - Pipeline FALHANDO (requisito do desafio):**

- [ ] Inserir um erro proposital no codigo (ex: dependencia vulneravel ou erro de lint)
  ```go
  // Exemplo: adicionar import nao usado (causa lint error)
  import "fmt"  // nao usado - golangci-lint vai reclamar
  ```
- [ ] Fazer push e mostrar o pipeline falhando no GitHub Actions
- [ ] Destacar o estagio que falhou e o motivo

**Demonstracao 2 - Pipeline PASSANDO:**

- [ ] Corrigir o erro
- [ ] Fazer push e mostrar o pipeline passando por todos os 5 estagios
- [ ] Mostrar os logs de cada estagio:
  - Build compilando com sucesso
  - Lint sem erros
  - Trivy reportando vulnerabilidades (sem bloquear)
  - gosec/bandit executando SAST
  - Docker image buildada e pushada para ECR
  - Commit automatico do bot no gitops/

**Fala sugerida:**
> "O pipeline implementa DevSecOps com SCA via Trivy para verificar dependencias vulneraveis, e SAST via gosec para Go e bandit para Python. Se uma vulnerabilidade critica for encontrada, o pipeline pode ser configurado para bloquear."

---

### Bloco 3: GitOps - Atualizacao Automatica (3-4 min)

**O que mostrar:**

- [ ] Abrir o historico de commits no GitHub
- [ ] Mostrar o commit automatico do `github-actions[bot]`:
  ```
  chore: update auth-service image to <commit-sha>
  ```
- [ ] Abrir o arquivo `gitops/auth-service/deployment.yaml` e mostrar a tag da imagem atualizada:
  ```yaml
  image: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/auth-service:<commit-sha>
  ```
- [ ] Explicar que os **secrets nao estao no git** — sao gerenciados externamente via scripts (`generate-secrets.sh`)
- [ ] Explicar o fluxo: CI faz push da imagem pro ECR e atualiza o manifesto GitOps automaticamente

**Fala sugerida:**
> "Ao final do pipeline de CI, um job automatico atualiza a tag da imagem no repositorio GitOps. Isso desacopla o CI do deploy - quem faz o deploy e o ArgoCD. Os secrets sao gerenciados fora do git por seguranca, usando scripts que leem automaticamente o output do Terraform."

---

### Bloco 4: ArgoCD - Sync Automatico (3-4 min)

**O que mostrar:**

- [ ] Abrir a interface web do ArgoCD no browser
  - URL: `https://<argocd-loadbalancer-hostname>`
  - Login: admin / `<senha obtida do secret>`
- [ ] Mostrar o dashboard com os 6 Applications:
  - auth-service (Synced/Healthy)
  - flag-service (Synced/Healthy)
  - targeting-service (Synced/Healthy)
  - evaluation-service (Synced/Healthy)
  - analytics-service (Synced/Healthy)
  - togglemaster-shared (Synced/Healthy)
- [ ] Clicar em uma Application (ex: auth-service) e mostrar:
  - Arvore de recursos (Deployment, Service, ReplicaSet, Pods)
  - Status de sync
  - Historico de sync (mostrar o sync mais recente com a tag do commit)
- [ ] Mostrar no terminal que os pods estao com a imagem nova:
  ```bash
  kubectl get pods -n togglemaster -l app=auth-service -o jsonpath='{.items[0].spec.containers[0].image}'
  ```

**Fala sugerida:**
> "O ArgoCD monitora o repositorio GitOps a cada 3 minutos. Quando detecta a mudanca no deployment.yaml, sincroniza automaticamente com o cluster EKS, fazendo rolling update dos pods."

---

### Bloco 5: Verificacao Final (1-2 min)

**O que mostrar:**

- [ ] Todos os pods rodando:
  ```bash
  kubectl get pods -n togglemaster
  ```
- [ ] Health check de um servico:
  ```bash
  curl http://localhost:8001/health
  # {"status":"ok","version":"1.1.0"}
  ```
- [ ] Resumir o fluxo completo:
  ```
  Dev Push → GitHub Actions (Build/Lint/Security/Docker/ECR) → GitOps Update → ArgoCD Sync → Pods Updated
  ```

---

### Encerramento (1 min)
- [ ] Resumir decisoes tecnicas:
  - Monorepo com 3 camadas (terraform, microservices, gitops)
  - AWS Academy com LabRole (sem IAM)
  - 5 pipelines independentes com DevSecOps
  - ArgoCD auto-sync com selfHeal
  - Secrets gerenciados fora do git, com scripts de automacao
  - `permissions: contents: write` no job (menor privilegio)
- [ ] Mencionar desafios encontrados (credenciais temporarias, CVEs em upstream, gosec version, secrets no git)
- [ ] Agradecer

---

## Checklist de Entregaveis (conforme PDF)

### Video de Demonstracao (ate 20 min)
- [ ] IaC: Mostrar `terraform plan` e `terraform apply` (ou resultado na AWS)
- [ ] Pipeline DevSecOps: Mostrar pipeline FALHANDO e depois PASSANDO
- [ ] GitOps: Mostrar pipeline atualizando tag da imagem no repo GitOps
- [ ] ArgoCD: Mostrar ArgoCD detectando mudanca e sincronizando

### Codigo Fonte no Repositorio
- [x] Terraform bem estruturado e componentizado (`terraform/modules/`)
- [x] Workflows GitHub Actions com DevSecOps (`.github/workflows/`)
- [x] Manifestos Kubernetes ajustados para GitOps (`gitops/`)

### Relatorio de Entrega (PDF ou TXT)
- [ ] Nomes dos participantes
- [ ] Link da documentacao e do video
- [ ] Resumo dos desafios encontrados e decisoes tomadas (ver `docs/RESUMO-EXECUTIVO.md`)
- [ ] Print da estimativa de custos da AWS (usar AWS Pricing Calculator)

---

## Dicas para o Video

1. **Prepare o ambiente antes** - Suba tudo antes de gravar. Mostre o `terraform apply` ja com output, ou rode `terraform plan` ao vivo (rapido)
2. **Use 2 janelas** - Terminal + Browser (GitHub Actions / ArgoCD)
3. **Erro proposital** - Para o demo do pipeline falhando, use algo simples como um import nao usado em Go (erro de lint) ou adicione uma dependencia com CVE
4. **Narrar enquanto espera** - O pipeline leva ~5 min; explique a arquitetura enquanto espera
5. **Tenha o ArgoCD aberto** - Mostre o sync acontecendo em tempo real
6. **Mostre o commit do bot** - E a prova visual mais clara do GitOps funcionando

---

## Sugestao de Erro Proposital para Demo

### Opcao A: Erro de Lint (mais simples)
```go
// Em microservices/auth-service/handlers.go, adicionar:
import "fmt"  // import nao utilizado
```
O golangci-lint vai falhar. Depois remova e push novamente.

### Opcao B: Dependencia Vulneravel
```bash
# Em microservices/auth-service/go.mod, adicionar uma lib antiga:
go get golang.org/x/text@v0.3.0  # versao com CVE conhecida
```
O Trivy vai reportar. Depois atualize para versao segura.

### Opcao C: Erro no gosec (SAST)
```go
// Em microservices/auth-service/main.go, adicionar:
password := "hardcoded123"  // gosec G101: hardcoded credentials
```

---

## Estimativa de Custos AWS (para o Relatorio)

Usar o [AWS Pricing Calculator](https://calculator.aws/) com:

| Servico | Tipo | Qtd | Custo Estimado/Mes |
|---------|------|-----|-------------------|
| EKS | Cluster | 1 | ~$73 |
| EC2 (EKS Nodes) | t3.medium | 2 | ~$61 |
| RDS PostgreSQL | db.t3.micro | 3 | ~$44 |
| ElastiCache | cache.t3.micro | 1 | ~$12 |
| NAT Gateway | - | 1 | ~$32 |
| SQS | Standard | 1 | < $1 |
| DynamoDB | On-demand | 1 | < $1 |
| ECR | 5 repos | 5 | < $1 |
| S3 (tfstate) | - | 1 | < $1 |
| **TOTAL ESTIMADO** | | | **~$224/mes** |

> **Nota:** AWS Academy nao cobra - esses valores sao para referencia do relatorio.
