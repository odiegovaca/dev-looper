---
description: Preparar release de produção consolidando versões RC em versão estável
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Versão de release (opcional, ex: /release 2.5.0)"
---

# /release - Release

## Processo

### 1 — Preparar Branch, Versão e Branch de Release

```bash
.github/scripts/release-prepare.sh "$ARGUMENTS"
```

### 2 — Validar

```bash
.github/scripts/validate.sh test lint build
```

### 3 — Commit e PR

Definir resumo de 2-4 linhas (baseado no CHANGELOG consolidado) e chamar:

```bash
.github/scripts/release-finalize.sh <<'EOF'
<resumo consolidado do CHANGELOG>
EOF
```
