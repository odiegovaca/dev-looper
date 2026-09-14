---
description: Preparar release de produção consolidando versões RC em versão estável
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Versão de release (opcional, ex: /release 2.5.0)"
---

# /release - Release

## Processo

### 1 — Preparar Branch, Versão e Branch de Release

```bash
.github/scripts/release-prepare.sh "$ARGUMENTS"
```

Montar `manage_todo_list` com os passos 2 a 4 antes de continuar.

### 2 — Validar

```bash
.github/scripts/validate.sh test lint build
```

Se falhar: identificar causa e corrigir antes de prosseguir (máx 3 iterações); se persistir, parar e reportar ao usuário.

### 3 — Commit e PR

Definir resumo de 2-4 linhas (baseado no CHANGELOG consolidado) e chamar:

```bash
.github/scripts/release-finalize.sh <<'EOF'
<resumo consolidado do CHANGELOG>
EOF
```

### 4 — Confirmar

Mostrar no chat, sem alterações, a saída de `release-finalize.sh` do passo 3.
