# Lessons Learned - Uso Eficiente do Claude Code

Licoes aprendidas durante o desenvolvimento do ToggleMaster Fase 3, para otimizar o uso do Claude Code em projetos futuros.

---

## 1. Comece com um CLAUDE.md

**O que e:** Um arquivo na raiz do projeto com todas as convencoes, decisoes tecnicas e "armadilhas" do projeto.

**Por que importa:** Sem ele, cada nova sessao do Claude precisa "redescobrir" o projeto — lendo arquivos, entendendo padroes, aprendendo com erros. Com ele, o Claude ja sabe tudo desde a primeira mensagem.

**O que incluir:**
- Arquitetura do projeto (servicos, linguagens, portas)
- Convencoes criticas (ex: "header e Authorization: Bearer, NAO X-Master-Key")
- Armadilhas conhecidas (ex: "sed do macOS nao suporta \s, usar python3")
- Ordem de execucao de scripts
- O que NUNCA fazer (ex: "secrets nunca no git")

**Impacto estimado:** ~30% de economia de tokens por sessao.

**Exemplo real:** Neste projeto, gastamos tokens significativos redescbrindo que:
- O header da API era `Authorization: Bearer` (nao `X-Master-Key`)
- `sed` do macOS nao funciona com `\s`
- Docker build precisa vir ANTES de ArgoCD Applications
- `permissions: contents: write` vai no job, nao no workflow

Tudo isso poderia ter sido evitado com um CLAUDE.md desde o inicio.

---

## 2. Quebre Tarefas Grandes em Sessoes Menores

**O problema:** Neste projeto, fizemos tudo numa sessao so — extracoes de secrets, criacao de scripts, execucao do pipeline, correcao de bugs, atualizacao de docs. O contexto estourou e precisamos de uma sessao de continuacao.

**A solucao:** Dividir em sessoes focadas:

| Sessao | Tarefa | Estimativa |
|--------|--------|------------|
| 1 | Extrair secrets dos deployments, criar .example, atualizar .gitignore | 15 min |
| 2 | Criar 5 scripts de automacao | 20 min |
| 3 | Executar pipeline e corrigir bugs | 30 min |
| 4 | Atualizar documentacao | 15 min |

**Beneficio:** Cada sessao comeca limpa, sem bagagem de contexto anterior. Se algo falhar, so aquela sessao precisa ser refeita.

**Impacto estimado:** ~40% de economia (evita estouro de contexto e reprocessamento).

---

## 3. Instrucoes Especificas > Instrucoes Abertas

**Ruim (gasta muitos tokens):**
> "Certifique-se que os scripts representem todas as correcoes"

O Claude precisa: reler todos os scripts, reler o historico da sessao, comparar cada detalhe, identificar divergencias. Isso gasta dezenas de tool calls.

**Bom (cirurgico):**
> "No generate-api-key.sh linha 58: troque X-Master-Key por Authorization: Bearer. Linha 59: troque description por name."

O Claude faz 1 edit e pronto.

**Regra pratica:** Se voce sabe o que precisa mudar, diga exatamente. Use instrucoes abertas apenas quando realmente nao sabe o que procurar.

**Impacto estimado:** ~25% de economia por tarefa.

---

## 4. Commits Frequentes = Checkpoints Seguros

**O problema:** Se o contexto estoura no meio de 20 mudancas nao commitadas, a proxima sessao pode nao saber exatamente o que ja foi feito vs. o que falta.

**A solucao:** Pedir commit a cada bloco logico de mudancas:

```
"Commite as mudancas dos workflows"
...trabalho...
"Commite os scripts de automacao"
...trabalho...
"Commite as atualizacoes de docs"
```

**Beneficio:** Se o contexto estourar entre o 2o e 3o commit, a proxima sessao ve claramente pelo `git log` e `git status` o que ja foi feito.

**Impacto estimado:** ~20% de economia em sessoes de continuacao.

---

## 5. Resumo Manual na Continuacao

**O que acontece por padrao:** Quando o contexto estoura, o Claude gera um resumo automatico. Na proxima sessao, ele precisa processar esse resumo enorme para entender onde parou.

**Melhor abordagem:** Comece a nova sessao com um resumo curto e preciso:

> "Sessao anterior: extrai secrets dos deployments, criei 5 scripts, executei o pipeline. Faltam 3 fixes: (1) generate-api-key.sh header errado, (2) setup-full.sh sem Docker step, (3) update-aws-credentials.sh sem aws configure fallback."

**Por que funciona:** O Claude nao precisa processar centenas de linhas de resumo automatico. Ele ja sabe exatamente o que fazer.

**Impacto estimado:** ~15% de economia na sessao de continuacao.

---

## 6. Use o Modo Plan para Decisoes Arquiteturais

**Quando usar:** Antes de tarefas que envolvem decisoes (ex: "como gerenciar secrets?", "como estruturar os scripts?").

**Como usar:** Digite `/plan` antes de pedir a implementacao. O Claude vai:
1. Explorar o codebase
2. Propor uma abordagem
3. Esperar sua aprovacao
4. So entao implementar

**Beneficio:** Evita o Claude implementar algo que voce vai pedir para refazer. Neste projeto, se tivessemos planejado a arquitetura de secrets antes, teriamos evitado varias iteracoes.

---

## 7. Paralelize Tarefas Independentes

**O que o Claude faz bem:** Executar multiplas tool calls em paralelo quando as tarefas sao independentes.

**Como aproveitar:** Agrupe pedidos independentes numa unica mensagem:

> "Atualize os 3 docs: ROTEIRO-COMPLETO (fix header API), RESUMO-EXECUTIVO (fix Trivy exit-code), GUIA-APRESENTACAO (fix exemplo de commit)"

O Claude pode ler os 3 arquivos em paralelo e fazer as edicoes de uma vez.

**Anti-pattern:** Pedir uma mudanca por mensagem, esperando a resposta de cada uma.

---

## 8. Nao Repita Contexto que o Claude ja Tem

**Desnecessario:**
> "No arquivo scripts/generate-api-key.sh que esta em /Users/luiz/FIAP/FASE3/TC3-ToggleMaster/scripts/generate-api-key.sh, que e um script bash que gera API keys..."

**Suficiente:**
> "No generate-api-key.sh, troque o header na linha 58"

O Claude ja conhece o projeto, os paths e os arquivos se ele ja leu o CLAUDE.md ou ja interagiu com eles na sessao.

---

## 9. Use Agentes para Tarefas de Pesquisa

**Quando usar:** Para buscas abertas no codebase (ex: "onde usamos X-Master-Key?", "quais arquivos referenciam ECR?").

**Beneficio:** O agente roda em paralelo, explorando multiplos arquivos sem gastar seu contexto principal.

**Como:** O Claude automaticamente usa agentes Explore quando faz sentido. Mas voce pode sugerir:
> "Busque em todos os arquivos onde aparece X-Master-Key"

---

## 10. Tabela de Referencia Rapida

| Situacao | Abordagem | Economia |
|----------|-----------|----------|
| Inicio de projeto | Criar CLAUDE.md com convencoes | ~30% |
| Tarefa grande (>1h) | Quebrar em sessoes de 15-30min | ~40% |
| Sabe o que mudar | Instrucao especifica com linha/arquivo | ~25% |
| Bloco de trabalho concluido | Pedir commit | ~20% |
| Continuando sessao anterior | Resumo manual de 2-3 linhas | ~15% |
| Decisao arquitetural | Usar /plan antes | Evita retrabalho |
| Multiplas mudancas independentes | Agrupar num unico pedido | ~15% |

---

## Metricas Reais Deste Projeto

| Metrica | Valor |
|---------|-------|
| Sessoes necessarias | 3 (2 estouraram contexto) |
| Arquivos modificados | ~25 |
| Arquivos criados | ~12 (scripts, examples, docs) |
| Bugs descobertos na execucao | 9 |
| Bugs que CLAUDE.md teria evitado | 4 (header, sed, ordem Docker, permissions) |
| Estimativa de economia com CLAUDE.md | ~45% dos tokens totais |

---

## Conclusao

A maior licao: **investir 10 minutos criando um CLAUDE.md economiza horas de tokens**. E como documentar o projeto para um novo desenvolvedor — so que o "novo desenvolvedor" e o Claude a cada nova sessao.

A segunda maior licao: **tarefas menores e focadas > uma sessao monolitica**. O contexto do Claude e finito. Respeitar esse limite e planejar em torno dele e a chave para produtividade.
