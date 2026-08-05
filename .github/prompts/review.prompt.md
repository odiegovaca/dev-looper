---
description: Executar code review crítico do código modificado na branch atual
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Branch base (padrão: origin/develop ou branch de integração)"
---

# /review - Code Review

Execute revisão crítica do código modificado na branch atual.

## Execução

### 1. Identificar Arquivos

```bash
INTEGRATION_BRANCH=$(# ler de copilot-instructions.md)
.github/scripts/changed-files.sh $INTEGRATION_BRANCH
```

### 2. Analisar Cada Arquivo

Para cada arquivo modificado:

1. Ler conteúdo completo
2. Ler diff: `git diff $MERGE_BASE..HEAD -- arquivo`
3. Analisar em todas as categorias:
   - **Padrões do projeto** (seguindo `copilot-instructions.md`)
   - **Qualidade e legibilidade**
   - **Simplicidade** (over-engineering?)
   - **Testes** (cobertura adequada?)
   - **Documentação** (pública e interna)
   - **Performance** (N+1 queries, loops desnecessários)
   - **Segurança** (OWASP Top 10, dados sensíveis expostos)
4. Por problema: número sequencial, severidade (CRITICAL/HIGH/MEDIUM/LOW), local (arquivo:linha), código problemático, explicação, solução sugerida

### 3. Gerar Relatório

Extrair `{N}` do nome da branch atual (`feature/{N}-nome-descritivo` → `{N}`) e calcular `{seq}`:

```bash
N=$(git branch --show-current | sed -E 's#^[a-z]+/([0-9]+)-.*#\1#')
SEQ=$(( $(ls docs/reviews/review-${N}-*.md 2>/dev/null | wc -l) + 1 ))
```

Criar `docs/reviews/review-{N}-{seq}.md` com:

1. **Summary**: `data` (YYYY-MM-DD-HHMMSS), estatísticas por criticidade, pontos fortes, veredicto
2. **Análise por arquivo**: Problemas com numeração global contínua
3. **Recomendações**: Must Have (bloqueantes) / Should Have / Nice to Have

### 4. Mostrar Sumário no Chat

```markdown
## Code Review Completo

**Relatório:** `docs/reviews/review-{N}-{seq}.md`
**Problemas:** N critical, N high, N medium, N low

### Veredicto

[APROVADO | APROVADO COM RESSALVAS | REPROVADO]
```

## Próximos Passos

- ✅ **Sem critical ou high**: `/rc` para criar o PR
- ⚠️ **Apenas high**: `/fix-review high` para corrigir problemas importantes, depois `/rc`
- ❌ **Com critical**: `/fix-review critical` e `/fix-review high` antes de prosseguir
