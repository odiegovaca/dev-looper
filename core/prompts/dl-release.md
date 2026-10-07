---
description: Preparar release de produção consolidando versões RC em versão estável
tools: [read, edit, search, execute]
argument-hint: "Versão de release (opcional, ex: /dl-release 2.5.0)"
---

# /dl-release - Release

## Processo

### 1 — Preparar Branch, Versão e Branch de Release

```bash
{{SCRIPTS_DIR}}/release-prepare.sh "$ARGUMENTS"
```

### 2 — Validar

```bash
{{SCRIPTS_DIR}}/validate.sh test lint build
```

### 3 — Commit e PR

Definir resumo de 2-4 linhas (baseado no CHANGELOG consolidado) e chamar:

```bash
{{SCRIPTS_DIR}}/release-finalize.sh <<'EOF'
<resumo consolidado do CHANGELOG>
EOF
```
