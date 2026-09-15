---
description: Criar ou atualizar a issue GitHub de uma spec
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Caminho da spec (opcional, usa a unica spec aprovada se omitido)"
---

# /issue - Criar ou Atualizar Issue GitHub

```bash
.github/scripts/create-issue.sh [caminho-da-spec]
```

Em caso de erro o script não altera nada, e a mensagem no stderr já traz a correção — repasse-a, não contorne preenchendo valores na mão.

Exceção: em **múltiplas specs aprovadas**, pergunte ao usuário qual da lista usar e rode de novo com o caminho escolhido.
