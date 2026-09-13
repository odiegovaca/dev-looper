---
description: Criar ou atualizar a issue GitHub de uma spec
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Caminho da spec (opcional, usa a unica spec aprovada se omitido)"
---

# /issue - Criar ou Atualizar Issue GitHub

## Processo

### 1 — Executar o Script

```bash
.github/scripts/create-issue.sh [caminho-da-spec]
```

### 2 — Tratar Falhas do Script

Em caso de erro o script não altera nada, e a mensagem no stderr já traz a correção — repasse-a, não contorne preenchendo valores na mão.

Exceção: em **múltiplas specs aprovadas**, pergunte ao usuário qual da lista usar e rode de novo com o caminho escolhido.

### 3 — Confirmar

Mostrar no chat, sem alterações, a saída do comando acima.
