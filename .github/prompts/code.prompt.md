---
description: Implementar funcionalidade completa seguindo spec e padrões do projeto
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Caminho da spec ou descrição da funcionalidade"
---

# /code - Implement Feature

Você é um desenvolvedor especialista que implementa funcionalidades completas seguindo as especificações e padrões do projeto.

## Preparação

1. Leia a spec em `docs/issues/spec-*.md` — liste as disponíveis se não especificada
2. Verifique branch atual: se branch principal (`main`/`master`) ou de integração (`develop`), crie `feature/{N}-nome-descritivo` antes de começar, onde `{N}` é o número da issue lido do campo `**Issue**: #N` da spec — esse número é o identificador comum entre spec, issue e review; sem issue vinculada, perguntar ao usuário o número antes de criar a branch
3. **Leia `.github/copilot-instructions.md` completamente** — contém os padrões obrigatórios do projeto
4. Procure no código existente por funcionalidade ou padrão análogo relacionado à spec — evita reimplementar algo que já existe ou divergir de um padrão já estabelecido no projeto
5. Monte `manage_todo_list` com todas as tarefas antes de começar

## Ordem de Implementação

> ⚠️ Esta seção é gerada/adaptada pelo `/setup` para o stack do projeto.
> Se ainda estiver genérica, rode `/setup` para personalizar.

**CRUD Simples:**

```
Model/Entity → Repository → Service → Controller/Handler → DTOs → Module/Config → Docs
```

**Integração Externa:**

```
Client HTTP → Error Handling → Service → Endpoint → Config → Docs
```

**Event-Driven:**

```
Event Schema → Consumer/Listener → Handler → Repository → Config → Docs
```

### Fase 1 — Persistência (se houver)

Criar model/entity e repository seguindo os padrões em `copilot-instructions.md`:

- Tipos de coluna e convenções de nomenclatura do projeto
- Transações quando necessário
- **Sempre retornar plain objects/DTOs do repository** — nunca expor objetos ORM diretamente

### Fase 2 — Lógica de Negócio

- **DTOs de entrada/saída**: validação nos campos com annotations ou validators do stack
- **DTOs de integração externa**: quando o pacote da integração fornece interfaces tipadas, sempre implementá-las nas classes DTO (`implements IMinhaInterface`); manter esses DTOs simples e sem decorators/annotations extras — campos idênticos à interface
- **Instalação de pacotes de DTOs externos**: usar a versão padrão do projeto (ex: `^1.0.0-rc.1`); se o pacote não for encontrado no registry, perguntar ao usuário a versão correta antes de continuar
- **Service**: lógica de negócio, validações, sem lógica de infraestrutura
- **Tratamento de erros**: usar exceções/error types customizados do projeto (ver `copilot-instructions.md`)

### Fase 3 — Exposição (API/Controller/Handler)

- Seguir convenções REST/RPC do projeto
- HTTP codes corretos para cada operação
- Autenticação/autorização conforme padrão em `copilot-instructions.md`

### Fase 4 — Configuração

- Registrar componentes no container de DI do framework
- Documentar variáveis de ambiente necessárias

## Padrões Obrigatórios

Todos os padrões estão em `copilot-instructions.md`. Antes de implementar qualquer parte, verificar:

- **Exception handling**: usar tipos do projeto, não exceções genéricas
- **Logging**: usar o logger do projeto, nunca `console.log`/`System.out.println` em produção
- **Variáveis de ambiente**: sempre via função/método helper do projeto — nunca `process.env.X` ou `System.getenv()` diretamente
- **Segurança**: nunca logar tokens, senhas ou dados pessoais

## Fase 5 — Testes Básicos

Criar testes unitários para o código implementado, cobrindo:

- **Happy path**: fluxo principal bem-sucedido de cada método público
- **Casos de erro esperados**: erros tipados lançados conforme a spec
- **Mocks**: dependências externas (repository, serviços HTTP, integrações) sempre mockadas

Consultar `copilot-instructions.md` (seção Testing Conventions) para estrutura e localização dos testes.

> Testes de borda, cobertura de branches e casos extras ficam para o `/test`.

## Validação Final

Executar os comandos de validação definidos em `copilot-instructions.md` (seção "Development Commands"):

1. **Lint** — zero erros
2. **Build** — zero erros de compilação
3. **Testes** — testes básicos passando

## Próximos Passos

Ao concluir, sugerir:

```
✅ Implementação concluída. Próximos passos:

1. Revise as Changes da branch (git diff ou painel Source Control)
2. Se aprovado: git commit "feat: <descrição>"  ← checkpoint antes do review
3. /test    → completar cobertura ≥ 80% (casos de borda e gaps)
4. /review  → revisão de qualidade antes do PR
5. /rc      → criar PR
```

> O commit após sua revisão serve como checkpoint: qualquer diff posterior mostra
> apenas o que o review e o fix-review alteraram, separado da implementação original.
