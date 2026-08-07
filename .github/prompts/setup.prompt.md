---
description: Configurar o workflow de IA para este projeto — detecta stack e gera copilot-instructions.md
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Descrição do projeto (opcional, usada se não houver README)"
---

# /setup - Bootstrap do Workflow de IA

Configure o workflow de desenvolvimento com IA para este projeto. Detecta o stack automaticamente, faz perguntas pontuais e gera `.github/copilot-instructions.md` personalizado.

## Processo

### 1 — Verificar Pré-requisitos

```bash
command -v gh >/dev/null 2>&1 || {
  echo "❌ gh CLI não encontrado. Instale antes de continuar: https://cli.github.com"
  echo "   Consulte o README do dev-looper para instruções detalhadas."
  exit 1
}

gh auth status >/dev/null 2>&1 || {
  echo "❌ gh CLI não autenticado. Rode: gh auth login"
  exit 1
}
```

Se qualquer um dos comandos falhar, interromper imediatamente com a mensagem correspondente. Não prosseguir para os próximos passos — `/issue`, `/rc` e `/release` dependem de `gh` instalado e autenticado.

### 2 — Detectar Stack

Explorar o repositório e identificar: linguagem/runtime, framework, banco de dados (driver/ORM), CI/CD, comandos de instalação/teste/lint/build, estrutura real do código-fonte, variáveis de ambiente esperadas, contexto de negócio (via `README.md`, se existir), histórico de mudanças e versão atual (via `CHANGELOG.md`, se existir) e padrões reais de código (a partir de um arquivo representativo, ex: controller ou service principal). Usar julgamento sobre quais arquivos abrir e como buscar em cada caso.

### 3 — Perguntas Pontuais

Com base no que foi detectado, fazer **apenas as perguntas pontuais e fechadas que não puderam ser inferidas**. Máximo 5, feitas juntas numa única mensagem — não uma a uma — exceto quando uma pergunta depende da resposta de outra. O usuário pode responder só as que quiser.

### 4 — Gerar copilot-instructions.md

Usar `copilot-instructions.template.md` como base **na primeira execução**. Em execuções seguintes — o template já foi removido pela execução anterior (ver abaixo) — usar o `copilot-instructions.md` existente como base: atualizar apenas as seções afetadas pela mudança de stack detectada no Passo 2, preservando o restante do conteúdo já preenchido manualmente ou em execuções anteriores. Substituir **todos os `[DEFINIR: ...]`** que ainda existirem com informações reais detectadas ou informadas.

Gerar `.github/copilot-instructions.md` com:

1. **Project Overview**: Nome, propósito, stack
2. **Architecture**: Stack completo, estrutura de pastas real
3. **Key Conventions**: Padrões reais detectados no código — não inventar
4. **Development Commands**: aponta para `.github/scripts/validate.sh` (preenchido no Passo 5) em vez de embutir o comando bruto
5. **Integration Points**: APIs e sistemas externos detectados
6. **Common Pitfalls**: armadilhas óbvias do stack detectado, identificadas a partir do código e da documentação lidos no Passo 2
7. **Testing Conventions**: Padrão de teste do projeto com exemplo real
8. **Coverage Report**: aponta para `.github/scripts/coverage.sh` (preenchido no Passo 5 com o comando do stack — exemplos já no cabeçalho do próprio script) em vez de embutir o comando bruto
9. **Release Workflow**: Estratégia de branches detectada ou informada

> ⚠️ **Regra**: Se não souber, deixe `[DEFINIR: ...]` — não invente. Melhor incompleto e correto do que completo e errado.

Após gerar o arquivo, remover o template (não é mais necessário):

```bash
rm -f .github/copilot-instructions.template.md
```

### 5 — Configurar Scripts Determinísticos

Preencher `.github/scripts/*.sh` com os dados detectados no Passo 2: versão (`bump-version.sh`), cobertura (`coverage.sh`), comandos de teste/lint/build (`validate.sh`) e branches de release (`release-branches.sh`) — para que sejam calculados por script em vez de recalculados em prosa a cada execução.

1. **`bump-version.sh`**: preencher o array `VERSION_FILES` com os arquivos de versão detectados no Passo 2 — exemplos já no cabeçalho do script.
2. **`coverage.sh`**: preencher o corpo de `read_coverage()` (total) e `read_coverage_by_file()` (por arquivo, saída `arquivo,pct,total_statements`) com os comandos de cobertura do stack — exemplos de ambos já no cabeçalho do script. `rank_priority()` (usada por `/test` via `coverage.sh --priority` para ranquear gaps por ganho real, não só por %) já é genérica e não precisa ser preenchida — só processa a saída de `read_coverage_by_file()`. Se o stack não expuser total de statements por arquivo (ex: `go tool cover`), deixar a 3ª coluna vazia — `rank_priority()` cai de volta para ordenar só por pct nesse caso.
3. **`validate.sh`**: preencher os corpos de `run_test()`, `run_lint()` e `run_build()` com os comandos reais de teste, lint e build do stack detectado (a mesma tabela que hoje vai para a seção "Development Commands" do `copilot-instructions.md`).
4. **`release-branches.sh`**: preencher `PROD_BRANCH` e `INTEGRATION_BRANCH` com as branches detectadas no Passo 2 (a mesma info que hoje vai para a seção "Release Workflow" do `copilot-instructions.md`).
5. `chmod +x .github/scripts/*.sh`.
6. Checar sintaxe dos scripts preenchidos: `bash -n .github/scripts/{bump-version,coverage,validate,release-branches}.sh`. Corrigir qualquer erro antes de seguir — evita que um erro de shell só apareça bem depois, na primeira vez que `/code` ou `/rc` rodar `validate.sh`.
7. Na seção "Release Workflow" do `copilot-instructions.md`, substituir as linhas **Branch principal**/**Branch de integração** por uma única linha `- **Branches**: ver .github/scripts/release-branches.sh` — as demais linhas (Versionamento, Arquivos de versão, CHANGELOG) continuam em prosa.

### 6 — Adaptar code.prompt.md

Ler `.github/prompts/code.prompt.md`.

Substituir as fases da seção **"Implementação"** (Passo 3, subseções `3.N`) com fases específicas do stack detectado, seguindo o critério:

1. **Persistência** — modelos, entidades, migrations, repositórios (se houver banco)
2. **Lógica de negócio** — serviços, validações, DTOs, mapeamentos
3. **Exposição** — controllers, handlers, rotas, endpoints
4. **Configuração** — registro de dependências, variáveis de ambiente, wiring do framework

Usar os artefatos reais do stack detectado e os padrões observados no código do projeto. Se o projeto for frontend, adaptar as fases para tipos → data fetching → componente → testes.

### 7 — Confirmar

Mostrar resumo do que foi configurado:

```markdown
## ✅ Workflow configurado para [NOME DO PROJETO]

**Stack detectado:**
- Runtime: [...]
- Framework: [...]
- Banco: [...]

**Arquivos gerados/atualizados:**
- `.github/copilot-instructions.md` → [N] seções preenchidas, [M] com [DEFINIR] pendente
- `.github/prompts/code.prompt.md` → Fases adaptadas para [STACK]
- `.github/scripts/*.sh` → [lista dos scripts preenchidos no Passo 5: bump-version.sh, coverage.sh, validate.sh, release-branches.sh]

**Pendências (preencher manualmente):**
- [ ] [Lista de [DEFINIR] que ficaram em aberto em copilot-instructions.md]
- [ ] [Scripts que ficaram com corpo não configurado — ex: "run_lint não configurado" em validate.sh]

**Próximo passo:** `/spec <descrição da feature>` para começar o desenvolvimento
```
