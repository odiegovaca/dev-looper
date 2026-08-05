---
description: Mostrar snapshot do estado atual do workflow de desenvolvimento
agent: agent
tools: [read, search, execute]
---

# /status - Estado do Workflow

Snapshot conciso do estado atual do desenvolvimento.

## Coletar informações

Execute em paralelo:

**Branch e commits:**

```bash
git branch --show-current
PRODUCTION_BRANCH=$(# ler de copilot-instructions.md, padrão: main)
git log origin/$PRODUCTION_BRANCH..HEAD --oneline 2>/dev/null | head -10
git status --short
```

**Versão, cobertura, specs e último review:**

```bash
.github/scripts/status-snapshot.sh
```

Uma única chamada agrega tudo: `VERSION`, `COVERAGE` (ou "não disponível" se o script falhar — sugerir `/test`), lista de `SPECS` (extrair `Status` de cada uma) e `LATEST_REVIEW` (caminho do review mais recente da feature atual — se existir, ler e extrair data e contagem de problemas por criticidade).

## Apresentar Resultado

```markdown
## Status do Workflow

**Branch:** feature/nome-da-feature
**Versão:** X.Y.Z-rc.N
**Commits à frente:** N commit(s)
**Mudanças pendentes:** X arquivos

**Specs:**

- `spec-nome.md` → Aprovado ✅
- `spec-outra.md` → Rascunho 📝

**Cobertura:** XX% (meta: 80%)
**Último review:** YYYY-MM-DD — N critical, N high, N medium, N low

**Sugestão de próximo passo:** /test | /review | /rc
```

Determinar o próximo passo sugerido com base no estado:

- Em branch protegida (main/develop) sem work in progress → `/code` para começar (cria a branch automaticamente)
- Sem cobertura → `/test`
- Com cobertura, sem review recente → `/review`
- Com review sem critical ou high → `/rc`
- Com review com critical ou high → `/fix-review critical` ou `/fix-review high`
- Sem commits à frente em branch de feature → iniciar nova feature com `/spec`
