---
description: Criar issue GitHub a partir de uma spec aprovada
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Caminho da spec (opcional, usa spec aprovada mais recente se omitido)"
---

# /issue - Criar Issue GitHub

Cria issue GitHub a partir de uma especificação aprovada.

## Processo

### 1. Localizar Spec

Se caminho fornecido, usar diretamente. Senão, buscar em `docs/issues/`:

```bash
ls docs/issues/spec-*.md 2>/dev/null
```

Para cada spec encontrada, verificar o `Status`. Usar a spec com status `Aprovado`.

Se múltiplas aprovadas: listar e pedir ao usuário para escolher.  
Se nenhuma aprovada: informar e sugerir `/spec` para aprovar.

### 2. Extrair Informações

Da spec selecionada, extrair:

- **Título**: Nome da funcionalidade
- **Contexto e Objetivo**: Para o corpo da issue
- **Critérios de Aceite**: Lista de checkboxes
- **Labels**: Inferir (ex: `feature`, `bug`, `improvement`)
- **Milestone**: Verificar se existe milestone adequado

### 3. Criar Issue

```bash
gh issue create \
  --title "[Título da funcionalidade]" \
  --body "$(cat <<'EOF'
## Contexto
[contexto da spec]

## Objetivo
[objetivo da spec]

## Critérios de Aceite
- [ ] [critério 1]
- [ ] [critério 2]

## Spec
`docs/issues/spec-[nome].md`
EOF
)" \
  --label "feature"
```

### 4. Atualizar Spec

Adicionar número da issue à spec:

```markdown
**Issue**: #[número]
```

Atualizar status para `Issue criada`.

## Próximos Passos

Ao concluir, sugerir:

```
✅ Issue #N criada. Próximo passo: /code para começar o desenvolvimento.
```
