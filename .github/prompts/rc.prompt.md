---
description: Finalizar feature branch e criar Pull Request com versionamento RC
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Tipo de versão: patch, minor ou major (ex: /rc patch, /rc minor cobertura ok)"
---

# /rc - RC Pull Request

Finaliza feature/fix branches e cria Pull Requests para a branch de integração com versionamento RC.

## Regra de Aceitação de Entrada

Se o usuário informar tipo de versão (`patch`/`minor`/`major`) ou cobertura OK, aceite e pule as etapas de descoberta. Exemplos: `/rc patch`, `/rc minor cobertura ok`.

## Workflow

### Step 1 — Verificar Branch

```bash
CURRENT_BRANCH=$(git branch --show-current)
```

Ler `copilot-instructions.md` para identificar branches protegidas (produção e integração, ex: `main`, `develop`).

- ❌ Abortar se branch principal ou de integração
- ✅ Continuar se `feature/**`, `fix/**`, `refactor/**`, `doc/**`

### Step 2 — Commitar Mudanças Pendentes

```bash
git status --porcelain
```

Se houver mudanças não commitadas: `git add . && git commit -m "chore: finalize feature implementation"`

### Step 3 — Determinar Tipo de Versão

```bash
git fetch origin
INTEGRATION_BRANCH=$(# ler de copilot-instructions.md, padrão: develop)
MERGE_BASE=$(git merge-base HEAD origin/$INTEGRATION_BRANCH)
CHANGED_FILES=$(git diff --name-only $MERGE_BASE..HEAD)
```

**Critérios (analisar arquivos reais):**

- 🔴 **MAJOR**: contrato de API quebrado (campos removidos de DTOs, endpoints removidos, mudanças de schema)
- 🟡 **MINOR**: novas funcionalidades (novos endpoints, novos módulos, novos campos opcionais)
- 🟢 **PATCH**: correções e melhorias (bugs, refactoring, testes, documentação, configuração)

### Step 4 — Calcular e Aplicar Versão RC

Ler arquivo de versão do projeto (detectar: `package.json`, `pom.xml`, `build.gradle`, `version.go`, `pyproject.toml`, `VERSION`):

```bash
# Exemplo para package.json:
MAIN_VERSION=$(git show origin/main:package.json | grep '"version"' | head -1 | sed 's/.*"version": "\(.*\)".*/\1/')
INTEGRATION_VERSION=$(git show origin/$INTEGRATION_BRANCH:package.json | grep '"version"' | head -1 | sed 's/.*"version": "\(.*\)".*/\1/')
```

Calcular próxima versão RC:

- Se `INTEGRATION_VERSION` já tem sufixo `-rc.N` para o mesmo bump → incrementar: `X.Y.Z-rc.(N+1)`
- Senão → nova versão: `X.(Y+1).0-rc.1` para MINOR, `X.Y.(Z+1)-rc.1` para PATCH

Atualizar **todos** os arquivos de versão do projeto (listados em `copilot-instructions.md`):

```bash
# Atualizar versão nos arquivos (variar por stack)
# package.json + package-lock.json (Node.js)
# pom.xml (Java Maven)
# build.gradle (Java Gradle)
# pyproject.toml (Python)
# VERSION file (genérico)
```

Adicionar entrada no `CHANGELOG.md`:

```markdown
## [X.Y.Z-rc.N] - DD/MM/AAAA

### [Adicionado|Corrigido|Alterado]

- descrição das mudanças
```

```bash
git add . && git commit -m "chore: bump version to X.Y.Z-rc.N"
```

### Step 5 — Validar CI

**5.1 Testes** (pular se usuário informou cobertura OK):

```bash
# Usar comando de testes de copilot-instructions.md
```

Verificar se passou. Se falhou: identificar causa e corrigir antes de prosseguir.

**5.2 Lint e Build:**

```bash
# Usar comandos de lint/build de copilot-instructions.md
```

### Step 6 — Push e PR

```bash
git push origin $CURRENT_BRANCH
```

Criar Pull Request via GitHub CLI:

```bash
gh pr create \
  --base $INTEGRATION_BRANCH \
  --title "feat: [título descritivo baseado nos commits]" \
  --body "$(cat <<'EOF'
## Resumo
[resumo das mudanças]

## Tipo de mudança
- [ ] PATCH (correção)
- [x] MINOR (nova funcionalidade)
- [ ] MAJOR (breaking change)

## Checklist
- [ ] Testes passando
- [ ] Lint passando
- [ ] CHANGELOG atualizado
- [ ] Documentação atualizada (se necessário)
EOF
)"
```

Apresentar link do PR criado.
