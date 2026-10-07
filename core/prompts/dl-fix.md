---
description: Aplicar correções do último code review por número, severidade ou todas
tools: [read, edit, search, execute, todo]
argument-hint: "Números e/ou severidades, combináveis, ou 'todos' (ex: /dl-fix 3, /dl-fix critical 7, /dl-fix medium low)"
---

# /dl-fix - Aplicar Correções do Code Review

## Processo

### 0 — Modo

```bash
.github/scripts/autonomous-mode.sh
```

### 1 — Selecionar

Sem argumento, perguntar ao usuário o que corrigir antes de seguir.

```bash
.github/scripts/fix-review-select.sh $ARGUMENTS
```

Com mais de um `SELECIONADOS`, montar {{TODO_LIST}} com um item por problema.

### 2 — Corrigir

Ler a `SPEC`. Para cada problema em `SELECIONADOS`: ler o arquivo inteiro, desenhar a correção que satisfaz o **Critério** do relatório, aplicá-la seguindo os "Padrões Obrigatórios" de `AGENTS.md`, sem tocar em código não relacionado, e marcar no TODO.

**Só aplicar o que cabe na spec.** Nos casos abaixo, não aplicar e não interromper — anotar como contestado e seguir para o próximo:

- **exige decisão** — a correção precisa de algo que a spec não diz (comportamento novo, escolha entre alternativas, contrato alterado). Anotar a proposta. Sem spec (`SPEC: nenhuma`), toda correção que muda comportamento observável cai aqui
- **não é problema** — lido o arquivo inteiro e a spec, o achado não se sustenta. Anotar o porquê

### 3 — Resolver os Contestados

Apresentar os contestados de uma vez, cada um com o critério do relatório, o caso (exige decisão ou não é problema) e a proposta ou o porquê. **A decisão é do usuário**; aplicar o que ele aceitar ainda aqui, para o passo 4 validar a correção.

No modo autônomo, não perguntar: cada contestado vira dispensa no passo 5, com o motivo marcado como do agente, e chega ao usuário no PR.

### 4 — Validar

```bash
.github/scripts/validate.sh lint build test
```

Corrigir o que falhar por causa de uma correção aplicada, em vez de deixar a falha para o `/dl-test`.

### 5 — Confirmar

```bash
.github/scripts/fix-review-finalize.sh \
  --applied "#1, #3" \
  --dismissed "#4: o usuário concordou que não é problema"
```

Um `--dismissed` por problema, com a decisão do usuário como motivo. Correção aceita no passo 3 conta como aplicada. No modo autônomo, o motivo é o do agente: `agente — exige decisão: <proposta>` ou `agente — não é problema: <por quê>`.

### 6 — Listar Lições para `/dl-lesson`

Só o que generaliza para além do arquivo corrigido. Nenhuma lição é resultado válido. Sem prosa livre fora do bloco:

```markdown
## 📚 Lições para /dl-lesson

- problema: #N [título curto]
  licao: [texto pronto para colar como argumento de /dl-lesson]
```

Nada que generalize: `Nenhuma lição nova identificada nesta execução.`
