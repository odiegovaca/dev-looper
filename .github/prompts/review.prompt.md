---
description: Executar code review crítico do código modificado na branch atual
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Branch de integração para comparar, sem prefixo origin/ (opcional, padrão: a do projeto)"
---

# /review - Code Review

**Este comando é somente leitura sobre o código revisado** — a única escrita permitida é a criação do relatório em `docs/reviews/`. Nunca editar os arquivos analisados.

## Processo

### 1 — Preparação

```bash
eval "$(.github/scripts/release-branches.sh)"
.github/scripts/review-prepare.sh "$INTEGRATION_BRANCH"
```

Se `$ARGUMENTS` trouxer uma branch, use-a no lugar de `$INTEGRATION_BRANCH`.

### 2 — Analisar Cada Arquivo

Para cada arquivo em `$DIFF`, escrever em `$REPORT` um bloco por achado (template abaixo), a partir do conteúdo completo do arquivo — não só o diff —, seguindo estes critérios:

- **Padrões do projeto** (seguindo `copilot-instructions.md`)
- **Qualidade e legibilidade**
- **Simplicidade** (over-engineering?)
- **Testes** (cobertura adequada?)
- **Documentação** (pública e interna)
- **Performance** (queries N+1, loops/alocações desnecessárias, chamadas bloqueantes)
- **Segurança** (OWASP Top 10, dados sensíveis expostos)
- **Tratamento de erros e edge cases** (exceções engolidas, entradas nulas/vazias/limite não tratadas)

#### 2.1 — Template do Bloco

````markdown
#### Problema {i} — {SEVERIDADE}

**Local:** `arquivo:linha`

```<linguagem>
[código problemático]
```

**Explicação:** [por que é um problema]

**Solução:** [como corrigir]
````

- `{i}` — número sequencial do problema (não confundir com `N` da feature)
- `{SEVERIDADE}`:
  - **CRITICAL** — segurança (vulnerabilidade exploitável, dado sensível exposto), perda/corrupção de dados, crash em produção
  - **HIGH** — bug funcional que afeta comportamento esperado do usuário/sistema
  - **MEDIUM** — manutenibilidade (duplicação, acoplamento, complexidade desnecessária)
  - **LOW** — estilo, nomenclatura, nitpick sem impacto funcional

### 3 — Gerar Relatório

```bash
.github/scripts/review-finalize.sh "$REPORT" "$DATA"
```

### 4 — Confirmar

Mostrar no chat, sem alterações, a saída de `review-finalize.sh` do passo anterior.
