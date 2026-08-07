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

Retorna, usados nos passos seguintes:

- `PROD_BRANCH` / `INTEGRATION_BRANCH` — branches protegidas
- `INTEGRATION_VERSION` — versão RC atual da integração
- `RELEASE_VERSION` — versão final (informada pelo usuário ou derivada removendo `-rc.N`)
- `COMMITS` — commits desde a última release em produção, um por linha

Montar `manage_todo_list` com os passos 2 a 6 antes de continuar.

### 2 — Consolidar CHANGELOG.md

A partir de `COMMITS` (retornado no passo 1), substituir **todas** as entradas RC por **uma única seção** de release, seguindo o template abaixo, e depois remover as seções `## [X.Y.Z-rc.N]` deste ciclo (entre a última release em produção e agora).

#### 2.1 — Template da seção de release

```markdown
## [X.Y.Z] - DD/MM/AAAA

### Adicionado

- Funcionalidade A (consolidado dos RCs)
- Funcionalidade B

### Corrigido

- Bug X

### Alterado

- Melhoria Y
```

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

### 6 — Pós-merge (orientações)

⚠️ **Não executar agora.** O PR ainda precisa ser revisado e mergeado por um humano. O comando abaixo é só para mostrar ao usuário como orientação, a ser executado por ele (ou por você, se pedido explicitamente) depois que o PR do passo 4 for aprovado e mergeado:

```bash
.github/scripts/release-postmerge.sh "$RELEASE_VERSION"
```

Cria e publica a tag `v$RELEASE_VERSION` e sincroniza `$INTEGRATION_BRANCH` com `$PROD_BRANCH`. Aborta sem criar nada se `$PROD_BRANCH` ainda não tiver a versão do release — sinal de que o PR do passo 4 não foi mergeado.
