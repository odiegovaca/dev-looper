---
description: Executar, corrigir e melhorar testes até meta de cobertura
tools: [read, edit, search, execute, todo]
argument-hint: "Meta de cobertura em % (opcional, padrão: a meta do projeto)"
---

# /dl-test - Completar Cobertura de Testes

Meta de **statements**: `{{SCRIPTS_DIR}}/coverage.sh --target`, ou o valor passado em `$ARGUMENTS`.

## Processo

### 0 — Modo

```bash
{{SCRIPTS_DIR}}/autonomous-mode.sh
```

### 1 — Executar e Corrigir

```bash
{{SCRIPTS_DIR}}/validate.sh test
```

Corrigir as falhas identificadas antes de seguir.

### 2 — Priorizar

```bash
{{SCRIPTS_DIR}}/coverage.sh --priority
```

`FASE1` traz os arquivos da branch, `FASE2` o resto do projeto, os dois já na ordem de ataque. Montar {{TODO_LIST}} com a `FASE1` antes de escrever.

### 3 — Completar

Escrever testes em até 3 ciclos de **escrever → `validate.sh test` → `coverage.sh` → `coverage.sh --priority`**, esgotando a `FASE1` antes de tocar na `FASE2`. Parar assim que a meta for atingida.

Se a meta não sair em 3 ciclos, seguir para o passo 4 mesmo assim e reportar como não atingida.

Ignorar código gerado, migrations e arquivos de configuração — não contam para a meta.

### 4 — Validar

```bash
{{SCRIPTS_DIR}}/validate.sh lint build
```

### 5 — Confirmar

```markdown
## Cobertura de Testes

**Statements:** XX% → YY% (+ganho%)
**Meta:** ZZ% — [ATINGIDA | NÃO ATINGIDA]
**Arquivos testados:** N (Fase 1: n1, Fase 2: n2)
```

Meta não atingida: listar em seguida as lacunas e os arquivos prioritários para cobertura manual.

### 6 — Fechamento

```bash
{{SCRIPTS_DIR}}/test-finalize.sh $ARGUMENTS
```

## Regras

- Não reescrever testes existentes que já passam — apenas complementar
- Nunca alterar código de produção para facilitar testes — adaptar os testes
- Estrutura, mocks e localização seguem a seção Testing Conventions de `AGENTS.md`
