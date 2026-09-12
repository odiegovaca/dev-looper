---
description: Preparar release de produção consolidando versões RC em versão estável
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Versão de release (opcional, ex: /release 2.5.0)"
---

# /release - Release

Prepara releases de produção consolidando versões RC da branch de integração em versões estáveis para produção.

## Processo

### 1 — Preparar Branch, Versão e Branch de Release

```bash
.github/scripts/release-prepare.sh "$ARGUMENTS"
```

Montar `manage_todo_list` com os passos 2 a 5 antes de continuar.

### 2 — Escrever a seção da release no CHANGELOG.md

O passo 1 deixou a seção `## [X.Y.Z]` criada e vazia no topo do arquivo. Escrever o corpo dela a partir de `RC_SECTIONS` e `COMMITS`, descrevendo o estado final contra a última versão em produção: cada mudança aparece uma vez, e o que nasceu e morreu dentro do ciclo (bug introduzido e corrigido, item adicionado e removido) não aparece.

### 3 — Validar

```bash
.github/scripts/validate.sh test lint build
```

Se falhar: identificar causa e corrigir antes de prosseguir (máx 3 iterações); se persistir, parar e reportar ao usuário.

### 4 — Commit e PR

Definir resumo de 2-4 linhas (baseado no CHANGELOG consolidado) e chamar:

```bash
.github/scripts/release-finalize.sh "$PROD_BRANCH" "$RELEASE_VERSION" <<'EOF'
<resumo consolidado do CHANGELOG>
EOF
```

### 5 — Confirmar

Mostrar no chat, sem alterações, a saída de `release-finalize.sh` do passo 4.
