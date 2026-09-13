---
description: Mostrar snapshot do estado atual do workflow de desenvolvimento
agent: agent
tools: [read, search, execute]
---

# /status - Estado do Workflow

## Processo

### 1 — Executar

```bash
eval "$(.github/scripts/release-branches.sh)"
.github/scripts/status-snapshot.sh "$PROD_BRANCH" "$INTEGRATION_BRANCH"
```

### 2 — Confirmar

Mostrar no chat, sem alterações, a saída do comando acima.
