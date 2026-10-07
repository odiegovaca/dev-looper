---
description: Executar code review crítico do código modificado na branch atual
tools: [read, edit, search, execute]
argument-hint: "--completo para revisar a branch inteira depois de um fix; branch de integração, sem prefixo origin/ (opcionais)"
---

# /dl-review - Code Review

**Este comando é somente leitura sobre o código revisado** — a única escrita permitida é a criação do relatório em `docs/reviews/`. Nunca editar os arquivos analisados.

## Processo

### 1 — Preparação

```bash
{{SCRIPTS_DIR}}/review-prepare.sh $ARGUMENTS
```

### 2 — Analisar Cada Arquivo

Para cada arquivo em `$DIFF`, escrever em `$REPORT` um bloco por achado (template abaixo), a partir do conteúdo completo do arquivo — não só o diff —, seguindo estes critérios:

- **Padrões do projeto** (seguindo `AGENTS.md`)
- **Qualidade e legibilidade**
- **Simplicidade** (over-engineering?)
- **Testes** (cobertura adequada?)
- **Documentação** (pública e interna)
- **Performance** (queries N+1, loops/alocações desnecessárias, chamadas bloqueantes)
- **Segurança** (OWASP Top 10, dados sensíveis expostos)
- **Tratamento de erros e edge cases** (exceções engolidas, entradas nulas/vazias/limite não tratadas)

#### 2.1 — Escopo Incremental

Com `ESCOPO=incremental`, o diff é só o que mudou desde o review anterior (no ciclo normal, o fix). Os arquivos continuam lidos inteiros, mas o review muda em três pontos:

1. **Conferir as correções:** para cada número em **Correções aplicadas** na seção Pós-fix de `$REVIEW_ANTERIOR`, verificar se o **Critério** daquele problema é verdade agora. Não sendo, escrever um bloco com a mesma severidade e o mesmo critério, com a Explicação começando por `Critério do #{i} do review anterior não satisfeito:`
2. **Bloco só para o que está no diff:** linhas mudadas ou o que elas quebram
3. **Grave fora do diff** (CRITICAL ou HIGH que já estava lá): escrever no fim do relatório, numa seção `## Fora do escopo`, com o template abaixo e o cabeçalho `#### Fora do escopo {i} — {SEVERIDADE}`. Não conta para o veredito nem reabre o ciclo; vai para o PR. MEDIUM e LOW fora do diff não entram

#### 2.2 — Template do Bloco

````markdown
#### Problema {i} — {SEVERIDADE}

**Local:** `arquivo:linha`

```<linguagem>
[código problemático]
```

**Explicação:** [por que é um problema]

**Critério:** [o que tem de ser verdade depois da correção]
````

- `{i}` — número sequencial do problema (não confundir com `N` da feature)
- **Critério** — comportamento ou propriedade verificável sem saber como a correção foi feita (ex.: "a migração roda uma vez por instalação, não a cada abertura"). Nunca o patch: a correção é desenhada no `/dl-fix`, com o arquivo inteiro e a spec à mão
- `{SEVERIDADE}`:
  - **CRITICAL** — segurança (vulnerabilidade exploitável, dado sensível exposto), perda/corrupção de dados, crash em produção
  - **HIGH** — bug funcional que afeta comportamento esperado do usuário/sistema
  - **MEDIUM** — manutenibilidade (duplicação, acoplamento, complexidade desnecessária)
  - **LOW** — estilo, nomenclatura, nitpick sem impacto funcional

### 3 — Gerar Relatório

```bash
{{SCRIPTS_DIR}}/review-finalize.sh "$REPORT" "$DATA" "$ESCOPO" "$BASE"
```
