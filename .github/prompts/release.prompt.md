---
description: Preparar release de produção consolidando versões RC em versão estável
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Versão de release (opcional, ex: /release 2.5.0)"
---

# /release - Release

Prepara releases de produção consolidando versões RC da branch de integração em versões estáveis para produção.

## Regra de Aceitação de Entrada

Se o usuário informar versão (ex: `/release 2.5.0`), aceitar e pular a etapa de descoberta.

## Workflow

### Step 1 — Verificar Ponto de Partida

```bash
CURRENT_BRANCH=$(git branch --show-current)
```

Ler `copilot-instructions.md` para identificar:

- Branch de produção (ex: `main`, `master`)
- Branch de integração (ex: `develop`, `staging`)

Se **não** estiver na branch de integração:

```bash
git log origin/$INTEGRATION_BRANCH..HEAD --oneline
```

- Se houver commits não mergeados: ⚠️ alertar — pode querer `/rc` primeiro
- Se não houver: prosseguir

```bash
git checkout $INTEGRATION_BRANCH && git pull origin $INTEGRATION_BRANCH
```

### Step 2 — Determinar Versão de Release

```bash
# Ler versão atual do arquivo de versão (package.json, pom.xml, etc.)
INTEGRATION_VERSION=$(# detectar e ler arquivo de versão)
RELEASE_VERSION=$(echo $INTEGRATION_VERSION | sed 's/-rc\..*//')
echo "Versão RC atual: $INTEGRATION_VERSION"
echo "Versão de release: $RELEASE_VERSION"
```

Se usuário forneceu versão, usar a fornecida.

### Step 3 — Criar Branch de Release

```bash
git checkout -b release/v$RELEASE_VERSION
```

### Step 4 — Atualizar Versões

Atualizar **todos** os arquivos de versão do projeto (listados em `copilot-instructions.md`) removendo o sufixo `-rc.N`:

- `package.json` + `package-lock.json` → `X.Y.Z`
- `pom.xml` / `build.gradle` → `X.Y.Z`
- `pyproject.toml` → `X.Y.Z`
- Outros arquivos de versão detectados pelo projeto

### Step 5 — Consolidar CHANGELOG.md

Coletar commits desde a última release em produção:

```bash
git log origin/$PRODUCTION_BRANCH..origin/$INTEGRATION_BRANCH --oneline --no-merges
```

Substituir **todas** as entradas RC por **uma única seção** de release:

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

Remover seções `## [X.Y.Z-rc.N]` antigas após consolidar.

### Step 6 — Validar

```bash
# Lint
# Build
# Testes
# (usar comandos de copilot-instructions.md)
```

Se qualquer etapa falhar: corrigir antes de prosseguir.

### Step 7 — Commit e PR

```bash
git add .
git commit -m "chore: release v$RELEASE_VERSION"
git push origin release/v$RELEASE_VERSION
```

Criar Pull Request para a branch de produção:

```bash
gh pr create \
  --base $PRODUCTION_BRANCH \
  --title "release: v$RELEASE_VERSION" \
  --body "$(cat <<'EOF'
## Release v$RELEASE_VERSION

### Resumo das mudanças
[consolidado do CHANGELOG]

### Checklist
- [ ] Todos os testes passando
- [ ] CHANGELOG consolidado
- [ ] Versões atualizadas
- [ ] Revisado por pelo menos 1 desenvolvedor
EOF
)"
```

### Step 8 — Pós-merge (orientações)

Após o PR ser aprovado e mergeado, informar ao usuário:

```bash
# 1. Criar tag de release
git checkout $PRODUCTION_BRANCH && git pull
git tag -a v$RELEASE_VERSION -m "Release v$RELEASE_VERSION"
git push origin v$RELEASE_VERSION

# 2. Sincronizar develop
git checkout $INTEGRATION_BRANCH
git merge $PRODUCTION_BRANCH
git push origin $INTEGRATION_BRANCH
```
