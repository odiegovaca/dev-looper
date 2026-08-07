---
description: Criar issue GitHub a partir de uma spec aprovada
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Caminho da spec (opcional, usa spec aprovada mais recente se omitido)"
---

# /issue - Criar Issue GitHub

Cria issue GitHub a partir de uma especificação aprovada. Título, corpo, label e atualização da spec são resolvidos por script — sem interpretação da LLM.

## Processo

### 1 — Executar o Script

```bash
.github/scripts/create-issue.sh [caminho-da-spec]
```

O script:

- Localiza a spec (arg ou busca `Status: Aprovada` em `docs/issues/`)
- Extrai o título (H1) da spec
- Usa o conteúdo integral da spec como corpo da issue
- Resolve o label a partir do campo `**Tipo**` da spec (`feature` ou `improvement`)
- Cria a issue via `gh issue create`
- Atualiza a própria spec: adiciona `**Issue**: #N` e muda `Status` para `Issue criada`
- Imprime `ISSUE_NUMBER`, `ISSUE_URL` e `SPEC_PATH`

### 2 — Tratar Falhas do Script

O script falha com mensagem no stderr e não cria nada em caso de erro. Trate cada caso:

- **Nenhuma spec aprovada**: informar e sugerir `/spec` para aprovar uma
- **Múltiplas specs aprovadas** (script lista os caminhos): apresentar a lista, perguntar ao usuário qual usar, rodar de novo passando o caminho escolhido
- **Spec com `Status` diferente de `Aprovada`**: informar o status atual e sugerir `/spec [identificador]` para aprovar
- **Campo `**Tipo**` ausente ou inválido**: informar e sugerir `/spec [identificador]` para preencher `feature` ou `improvement`

Não tente contornar essas falhas preenchendo valores manualmente — cada uma indica que a spec precisa ser corrigida antes de virar issue.

### 3 — Confirmar

```
✅ Issue #[ISSUE_NUMBER] criada: [ISSUE_URL]
   Spec atualizada: [SPEC_PATH] → Status: Issue criada
   Próximo passo: /code para começar o desenvolvimento.
```
