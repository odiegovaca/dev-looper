---
description: Executar, corrigir e melhorar testes até meta de cobertura
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Meta de cobertura em % (opcional, padrão: a meta do projeto)"
---

# /test - Completar Cobertura de Testes

Meta de **statements**: `.github/scripts/coverage.sh --target`, ou o valor passado em `$ARGUMENTS`.

## Processo

### 1 — Executar e Corrigir

```bash
.github/scripts/validate.sh test
```

Corrigir as falhas identificadas antes de seguir.

### 2 — Priorizar

```bash
.github/scripts/coverage.sh --priority
```

`FASE1` traz os arquivos da branch, `FASE2` o resto do projeto, os dois já na ordem de ataque. Montar `manage_todo_list` com a `FASE1` antes de escrever.

### 3 — Completar

Escrever testes em até 3 ciclos de **escrever → `validate.sh test` → `coverage.sh` → `coverage.sh --priority`**, esgotando a `FASE1` antes de tocar na `FASE2`. Parar assim que a meta for atingida.

Se a meta não sair em 3 ciclos, seguir para o passo 4 mesmo assim e reportar como não atingida.

Ignorar código gerado, migrations e arquivos de configuração — não contam para a meta.

### 4 — Validar

```bash
.github/scripts/validate.sh lint build
```

### 5 — Confirmar

```markdown
## Cobertura de Testes

**Statements:** XX% → YY% (+ganho%)
**Meta:** ZZ% — [ATINGIDA | NÃO ATINGIDA]
**Arquivos testados:** N (Fase 1: n1, Fase 2: n2)
```

## Regras

- Não reescrever testes existentes que já passam — apenas complementar
- Nunca alterar código de produção para facilitar testes — adaptar os testes
- Estrutura, mocks e localização seguem a seção Testing Conventions de `copilot-instructions.md`

## Próximos Passos

- ✅ **Meta atingida**: `git commit -m "test: completa cobertura"` como checkpoint, depois `/review`
- ⚠️ **Meta não atingida**: informar lacunas e arquivos prioritários para cobertura manual
