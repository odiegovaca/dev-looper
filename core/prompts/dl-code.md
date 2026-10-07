---
description: Implementar funcionalidade completa seguindo spec e padrões do projeto
tools: [read, edit, search, execute, todo]
argument-hint: "Caminho da spec ou descrição da funcionalidade"
---

# /dl-code - Implementar Funcionalidade

## Processo

### 0 — Modo

```bash
{{SCRIPTS_DIR}}/autonomous-mode.sh
```

### 1 — Preparação

1. **Leia `AGENTS.md` completamente**
2. Leia a spec em `docs/issues/spec-*.md` — liste as disponíveis se não especificada. Se o `Status` for `Rascunho`/`Em Revisão`, ou houver "Questões em Aberto" pendentes, avisar o usuário e confirmar antes de prosseguir — implementar spec incompleta gera requisito adivinhado
3. Confira a branch:

   ```bash
   {{SCRIPTS_DIR}}/code-branch.sh [caminho-da-spec]
   ```

   Com `BRANCH_OK=nao`, criar `feature/{FEATURE_N}-nome-descritivo` antes de começar. Com `FEATURE_N` vazio, perguntar o número da issue ao usuário primeiro.

4. Procure no código existente por funcionalidade ou padrão análogo relacionado à spec — evita reimplementar algo que já existe ou divergir de um padrão já estabelecido
5. Monte {{TODO_LIST}} com todas as tarefas antes de começar

### 2 — Implementação

Cada fase segue os padrões de `AGENTS.md` e só termina com o código dela conforme a seção "Padrões Obrigatórios".

#### 2.1 — Persistência (se houver)

Modelos, entidades, migrations e repositórios, com transação onde a operação precisar ser atômica.

#### 2.2 — Lógica de Negócio

Serviços, validações, mapeamentos e tratamento de erros. DTOs de entrada e saída levam as validações de campo do stack. O serviço não carrega lógica de infraestrutura.

#### 2.3 — Exposição (se houver)

Controllers, handlers, rotas ou endpoints, conforme o paradigma da funcionalidade, com o código de retorno correto para cada operação.

#### 2.4 — Configuração

Registro no container de dependências, variáveis de ambiente novas e documentação pública afetada.

#### 2.5 — Testes Básicos

Testes unitários do código implementado, cobrindo o fluxo principal de cada método público e os erros tipados que a spec prevê, com as dependências externas mockadas. Estrutura, nomes e localização seguem a seção Testing Conventions de `AGENTS.md`.

> Testes de borda, cobertura de branches e casos extras ficam para o `/dl-test`.

### 3 — Validação Final

```bash
{{SCRIPTS_DIR}}/validate.sh lint build test
```

Precisa terminar sem erro antes de prosseguir. `test` roda a suíte completa do projeto, não só os testes criados em 2.5.

### 4 — Fechamento

```bash
{{SCRIPTS_DIR}}/code-finalize.sh "<descrição curta da funcionalidade>"
```
