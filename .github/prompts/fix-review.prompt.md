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
.github/scripts/fix-review-select.sh $ARGUMENTS
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

Corrigir o que falhar por causa de uma correção aplicada, em vez de deixar a falha para o `/test`.

### 5 — Confirmar

```bash
.github/scripts/fix-review-finalize.sh \
  --applied "#1, #3" \
  --dismissed "#4: o usuário concordou que não é problema"
```

Um `--dismissed` por problema, com a decisão do usuário como motivo. Alternativa aceita no passo 3 conta como aplicada.

### 6 — Listar Lições para `/lesson`

Só o que generaliza para além do arquivo corrigido. Nenhuma lição é resultado válido. Sem prosa livre fora do bloco:

```markdown
## 📚 Lições para /lesson

- problema: #N [título curto]
  licao: [texto pronto para colar como argumento de /lesson]
```

Nada que generalize: `Nenhuma lição nova identificada nesta execução.`
