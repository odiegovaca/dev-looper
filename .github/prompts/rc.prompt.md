---
description: Finalizar feature branch e criar Pull Request com versionamento RC
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Tipo de versão: patch, minor ou major (ex: /rc patch)"
---

# /rc - RC Pull Request

Finaliza feature/fix branches e cria Pull Requests para a branch de integração com versionamento RC.

## Processo

### 1 — Preparar Branch e Determinar Tipo de Versão

```bash
.github/scripts/rc-prepare.sh "$ARGUMENTS"
```

Retorna, usados nos passos seguintes:

- `INTEGRATION_BRANCH` — reaproveitada no passo 4
- `FEATURE_N` — identificador da issue (mesmo usado por `/review`/`/fix-review`), usado no PR do passo 4; vazio se a branch não seguir `{tipo}/{N}-nome`
- `TIPO` — `patch`/`minor`/`major` se já informado; vazio se precisar ser inferido a seguir
- `CHANGED_FILES` — arquivos alterados em relação a `INTEGRATION_BRANCH`, um por linha

Montar `manage_todo_list` com os passos 2 a 5 antes de continuar.

**Se `TIPO` vazio, inferir analisando `CHANGED_FILES`:**

- 🔴 **MAJOR**: contrato de API quebrado (campos removidos de DTOs, endpoints removidos, mudanças de schema)
- 🟡 **MINOR**: novas funcionalidades (novos endpoints, novos módulos, novos campos opcionais)
- 🟢 **PATCH**: correções e melhorias (bugs, refactoring, testes, documentação, configuração)

### 2 — Calcular e Aplicar Versão RC

```bash
NEW_VERSION=$(.github/scripts/bump-version.sh $TIPO)
```

Adicionar entrada no `CHANGELOG.md`, usando `Unreleased` no lugar da data enquanto a versão está em RC (a data real entra quando o `/release` consolida):

```markdown
## [X.Y.Z-rc.N] - Unreleased

### [Adicionado|Corrigido|Alterado]

- descrição das mudanças
```

```bash
git add .
.github/scripts/protect-stage.sh
git commit -m "chore: bump version to $NEW_VERSION"
```

### 3 — Validar CI

```bash
.github/scripts/validate.sh test lint build
```

Se falhar: identificar causa e corrigir antes de prosseguir (máx 3 iterações); se persistir, parar e reportar ao usuário.

### 4 — Push e PR

Definir título descritivo (baseado nos commits) e resumo de 2-4 linhas (para `major`, destacar a breaking change) e chamar:

```bash
.github/scripts/create-pr.sh $INTEGRATION_BRANCH $TIPO $NEW_VERSION "<título>" "$FEATURE_N" <<'EOF'
<resumo das mudanças>
EOF
```

### 5 — Confirmar

Mostrar no chat, sem alterações, a saída de `create-pr.sh` do passo 4.
