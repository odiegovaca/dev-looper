---
description: Finalizar feature branch e criar Pull Request com versionamento RC
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Tipo de versão: patch, minor ou major (ex: /rc patch)"
---

# /rc - RC Pull Request

## Processo

### 1 — Preparar Branch e Determinar Tipo de Versão

```bash
.github/scripts/rc-prepare.sh "$ARGUMENTS"
```

Montar `manage_todo_list` com os passos 2 a 5 antes de continuar.

**Se o `TIPO` da saída vier vazio, inferir** a partir dos arquivos que o script listou:

- 🔴 **MAJOR**: contrato de API quebrado (campos removidos de DTOs, endpoints removidos, mudanças de schema)
- 🟡 **MINOR**: novas funcionalidades (novos endpoints, novos módulos, novos campos opcionais)
- 🟢 **PATCH**: correções e melhorias (bugs, refactoring, testes, documentação, configuração)

### 2 — Calcular e Aplicar Versão RC

```bash
NEW_VERSION=$(.github/scripts/bump-version.sh $TIPO)
```

O ciclo tem **uma única seção** no `CHANGELOG.md`: reescrever a do topo (criando-a na primeira vez) com o header na versão nova e o delta acumulado do ciclo, descrito contra a última versão em produção — cada mudança aparece uma vez, e o que nasceu e morreu dentro do ciclo não aparece.

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
.github/scripts/create-pr.sh $TIPO "<título>" <<'EOF'
<resumo das mudanças>
EOF
```

### 5 — Confirmar

Mostrar no chat, sem alterações, a saída de `create-pr.sh` do passo 4.
