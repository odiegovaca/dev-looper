---
description: Aplicar correções do último code review por número, severidade ou todas
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Números e/ou severidades, combináveis, ou 'todos' (ex: /fix-review 3, /fix-review critical 7, /fix-review medium low)"
---

# /fix-review - Aplicar Correções do Code Review

## Processo

### 1 — Selecionar

Sem argumento, perguntar ao usuário o que corrigir antes de seguir.

```bash
REPORT=$(.github/scripts/latest-review.sh)
.github/scripts/fix-review-select.sh "$REPORT" $ARGUMENTS
```

Com mais de um `SELECIONADOS`, montar `manage_todo_list` com um item por problema.

### 2 — Aplicar

Para cada problema em `SELECIONADOS`: ler o arquivo inteiro, aplicar a correção seguindo os "Padrões Obrigatórios" de `copilot-instructions.md`, sem tocar em código não relacionado, e marcar no TODO.

**Se a solução do relatório parecer errada, não aplicar e não interromper** — anotar como contestado e seguir para o próximo.

### 3 — Resolver os Contestados

Apresentar os contestados de uma vez, cada um com o que o relatório propôs, por que parece errado e a alternativa. **A decisão é do usuário**; aplicar o que ele aceitar ainda aqui, para o passo 4 validar a alternativa.

### 4 — Validar

```bash
.github/scripts/validate.sh lint build test
```

Se falhar por causa de uma correção aplicada, corrigir antes de prosseguir (máx 3 iterações); se persistir, parar e reportar ao usuário em vez de deixar a falha para o `/test`.

### 5 — Confirmar

```bash
.github/scripts/fix-review-finalize.sh "$REPORT" \
  --applied "#1, #3" \
  --dismissed "#4: o usuário concordou que não é problema"
```

`--applied`: corrigidos, inclusive por alternativa aceita no passo 3. `--dismissed`: nada a corrigir, com a decisão do usuário como motivo, uma flag por problema.

Mostrar no chat, sem alterações, a saída do script.

### 6 — Listar Lições para `/lesson`

Sempre incluir, para prevenir recorrência. De 1 a 6 lições, sem prosa livre fora do bloco:

```markdown
## 📚 Lições para /lesson

- problema: #N [título curto]
  regra_proposta: [texto pronto para colar como argumento de /lesson]
  destino: [arquivo — mesmo critério de classificação do passo 2 de /lesson]
```

Sem correção aplicada: `Nenhuma lição nova identificada nesta execução.`
