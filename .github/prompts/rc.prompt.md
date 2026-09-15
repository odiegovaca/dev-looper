---
description: Finalizar feature branch e criar Pull Request com versionamento RC
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Tipo de versão: patch, minor ou major (ex: /rc patch)"
---

# /rc - RC Pull Request

## Processo

### 1 — Preparar Branch e Determinar Tipo de Versão

```bash
.github/scripts/rc-prepare.sh "$ARGUMENTS"
```

**Se o `TIPO` da saída vier vazio, inferir** a partir dos arquivos que o script listou:

- 🔴 **MAJOR**: contrato de API quebrado (campos removidos de DTOs, endpoints removidos, mudanças de schema)
- 🟡 **MINOR**: novas funcionalidades (novos endpoints, novos módulos, novos campos opcionais)
- 🟢 **PATCH**: correções e melhorias (bugs, refactoring, testes, documentação, configuração)

### 2 — Versão e CHANGELOG

```bash
NEW_VERSION=$(.github/scripts/bump-version.sh $TIPO)
.github/scripts/changelog-section.sh "$NEW_VERSION"
```

Reescrever o corpo da seção com o delta acumulado do ciclo, descrito contra a última versão em produção: cada mudança aparece uma vez, e o que nasceu e morreu dentro do ciclo não aparece.

As subseções são as do [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) — só as que tiverem conteúdo no ciclo.

```bash
git add .
.github/scripts/protect-stage.sh
git commit -m "chore: bump version to $NEW_VERSION"
```

### 3 — Validar CI

```bash
.github/scripts/validate.sh test lint build
```

### 4 — Push e PR

Definir título descritivo (baseado nos commits) e resumo de 2-4 linhas (para `major`, destacar a breaking change) e chamar:

```bash
.github/scripts/create-pr.sh $TIPO "<título>" <<'EOF'
<resumo das mudanças>
EOF
```
