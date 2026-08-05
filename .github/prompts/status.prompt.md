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

**Versão atual** (detectar arquivo de versão):

```bash
grep '"version"' package.json 2>/dev/null | head -1
grep '<version>' pom.xml 2>/dev/null | head -2
cat VERSION 2>/dev/null
```

**Specs disponíveis:**

```bash
ls docs/issues/spec-*.md 2>/dev/null
```

Para cada spec, extrair `Status`.

**Último code review:**

```bash
ls -t docs/reviews/review-*.md 2>/dev/null | head -1
```

Se existir, extrair data e contagem de problemas por criticidade (critical/high/medium/low).

**Cobertura atual:**

Ler `copilot-instructions.md` (seção **Coverage Report**) e executar o comando documentado.
Se a seção não existir ou o comando falhar: exibir `não disponível (rode /test)`.

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
