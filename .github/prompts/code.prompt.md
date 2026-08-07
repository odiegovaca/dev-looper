---
description: Implementar funcionalidade completa seguindo spec e padrões do projeto
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Caminho da spec ou descrição da funcionalidade"
---

# /code - Implementar Funcionalidade

Você é um desenvolvedor especialista que implementa funcionalidades completas seguindo as especificações e padrões do projeto.

## Processo

### 1 — Preparação

1. **Leia `.github/copilot-instructions.md` completamente** — contém os padrões obrigatórios do projeto e a seção Arquivos Protegidos (nunca editar por este comando)
2. Leia a spec em `docs/issues/spec-*.md` — liste as disponíveis se não especificada. Se `Status` for `Rascunho`/`Em Revisão`, ou houver "Questões em Aberto" pendentes, avisar o usuário e confirmar antes de prosseguir — implementar spec incompleta gera requisito adivinhado
3. Verifique branch atual: rode `eval "$(.github/scripts/release-branches.sh)"` e compare com `git branch --show-current` — se for `$PROD_BRANCH` ou `$INTEGRATION_BRANCH`, crie `feature/{N}-nome-descritivo` antes de começar
   - `{N}` é o número da issue, lido do campo `**Issue**: #N` da spec — sem issue vinculada, perguntar ao usuário o número antes de criar a branch
   - Esse número é o identificador comum entre spec, issue e review
   - O padrão de nome da branch é lido de volta por `.github/scripts/feature-number.sh` (usado por `/review` e `/fix-review`) — não altere esse formato sem atualizar os dois
4. Procure no código existente por funcionalidade ou padrão análogo relacionado à spec — evita reimplementar algo que já existe ou divergir de um padrão já estabelecido no projeto
5. Monte `manage_todo_list` com todas as tarefas antes de começar

### 2 — Padrões Obrigatórios

Ler a seção "Padrões Obrigatórios" de `copilot-instructions.md`. Vale para todas as fases da implementação — verificar antes de considerar qualquer fase concluída.

### 3 — Implementação

#### 3.1 — Persistência (se houver)

Criar model/entity e repository seguindo os padrões em `copilot-instructions.md`:

- Tipos de coluna e convenções de nomenclatura do projeto
- Transações quando necessário
- **Sempre retornar plain objects/DTOs do repository** — nunca expor objetos ORM diretamente

#### 3.2 — Lógica de Negócio

- **DTOs de entrada/saída**: validação nos campos com annotations ou validators do stack
- **DTOs de integração externa**: quando o pacote da integração fornece interfaces tipadas, sempre implementá-las nas classes DTO (`implements IMinhaInterface`); manter esses DTOs simples e sem decorators/annotations extras — campos idênticos à interface
- **Instalação de pacotes de DTOs externos**: usar a versão padrão do projeto (ex: `^1.0.0-rc.1`); se o pacote não for encontrado no registry, perguntar ao usuário a versão correta antes de continuar
- **Service**: lógica de negócio, validações, sem lógica de infraestrutura
- **Tratamento de erros**: usar exceções/error types customizados do projeto (ver `copilot-instructions.md`)

#### 3.3 — Exposição (se houver)

- Seguir convenções REST/RPC/CLI/scheduler do projeto, conforme o paradigma da funcionalidade
- HTTP codes corretos para cada operação (quando houver API)
- Autenticação/autorização conforme padrão em `copilot-instructions.md`

#### 3.4 — Configuração

- Registrar componentes no container de DI (injeção de dependência) do framework
- **Docs**: variáveis de ambiente novas, documentação pública afetada (README, comentários de API, OpenAPI/Swagger) conforme convenção do projeto

#### 3.5 — Testes Básicos

Criar testes unitários para o código implementado, cobrindo:

- **Happy path**: fluxo principal bem-sucedido de cada método público
- **Casos de erro esperados**: erros tipados lançados conforme a spec
- **Mocks**: dependências externas (repository, serviços HTTP, integrações) sempre mockadas

Consultar `copilot-instructions.md` (seção Testing Conventions) para estrutura e localização dos testes.

> Testes de borda, cobertura de branches e casos extras ficam para o `/test`.

### 4 — Validação Final

```bash
.github/scripts/validate.sh lint build test
```

Precisa terminar sem erro antes de prosseguir. `test` roda a suíte completa do projeto, não só os testes criados em 3.5.

## Próximos Passos

Ao concluir, sugerir:

```markdown
✅ Implementação concluída. Próximos passos:

1. Revise as Changes da branch (git diff ou painel Source Control)
2. Se aprovado: git commit "feat: <descrição>"  ← checkpoint antes do review
3. /test    → completar cobertura até a meta do projeto (casos de borda e gaps)
4. /review  → revisão de qualidade antes do PR
5. /rc      → criar PR
```

> O commit após sua revisão serve como checkpoint: qualquer diff posterior mostra
> apenas o que o review e o fix-review alteraram, separado da implementação original.
