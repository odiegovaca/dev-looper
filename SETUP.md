# dev-looper

Workflow de desenvolvimento com GitHub Copilot Agent Mode.

Fornece um conjunto de comandos `/` que guiam o desenvolvedor por um ciclo completo de desenvolvimento — da especificação ao PR de produção — com guardrails, padrões do projeto e auto-melhoria incorporados.

---

## Pré-requisitos

- VS Code com extensão **GitHub Copilot** (com Agent Mode habilitado)
- Git configurado no projeto
- **`gh` CLI** — necessário para `/issue`, `/rc` e `/release` ([instalar](https://cli.github.com))

> O `/setup` valida esses pré-requisitos na inicialização e interrompe com mensagem clara se algo estiver faltando. **Execute `/setup` antes de qualquer outro comando do workflow.**

---

## Instalação (5 minutos)

### 1. Copiar os arquivos

```bash
cp -r .github/ /caminho/do/seu/projeto/.github/
```

> Se o projeto já tem `.github/`, mescle manualmente — não sobrescreva PRs/issues templates existentes.

### 2. Recarregar o VS Code

Após copiar os arquivos, recarregue a janela para que o Copilot reconheça os novos comandos `/`:

> `Ctrl+Shift+P` → **Developer: Reload Window**

> Os arquivos `.prompt.md` são indexados na abertura do workspace — sem reload, os comandos `/` não aparecem no chat.

### 3. Bootstrap automático

Abra o projeto no VS Code e execute no chat do Copilot:

```
/setup
```

O agente vai:

1. Detectar stack (linguagem, framework, banco, CI/CD)
2. Fazer perguntas pontuais sobre o que não conseguir inferir
3. Gerar `.github/copilot-instructions.md` personalizado para o projeto
4. Adaptar `.github/prompts/code.prompt.md` com os padrões do stack detectado

### 3. Validar

```
/status
```

Deve mostrar branch atual, versão e sugerir próximo passo.

---

## O Workflow

```
/spec        Escrever especificação funcional
/issue       Criar issue GitHub da spec
/code        Gerar código seguindo a spec e padrões do projeto
/test        Testes até meta de cobertura (padrão 80%)
/review      Revisão crítica com relatório e score
/fix-review  Aplicar correções do code review
/rc          PR → branch de integração (com versionamento RC)
/release     PR → produção (versão estável)
```

**Comandos auxiliares:**

```
/status      Snapshot: branch, versão, cobertura, último review
/lesson      Formalizar correção em instrução permanente
```

---

## Customização

### O arquivo central: `copilot-instructions.md`

Esse arquivo é o "onboarding do agente" — ele aprende o projeto lendo esse arquivo no início de cada sessão. Mantenha-o atualizado com:

- Stack e versões
- Padrões de código (exception handling, logging, auth)
- Comandos de desenvolvimento (`test`, `build`, `lint`)
- Armadilhas comuns (Common Pitfalls)
- Padrões de banco de dados

Use `/lesson` após qualquer correção manual para manter esse arquivo crescendo automaticamente.

### Adaptar os prompts

- **`code.prompt.md`**: Fases de implementação específicas do stack. Gerado automaticamente pelo `/setup` mas pode ser ajustado manualmente.
- **`rc.prompt.md`**: Ajustar se o projeto não usar versionamento RC ou tiver arquivos de versão diferentes de `package.json`.
- **`release.prompt.md`**: Ajustar branch de produção se não for `main`.

Os demais prompts buscam padrões e comandos em `copilot-instructions.md` — nenhum precisa de alteração manual após o `/setup`.

---

## Arquitetura

```
.github/
  copilot-instructions.md      ← Conhecimento do projeto (gerado por /setup)
  prompts/                     ← Todos os comandos / acessíveis no chat
  skills/                      ← Conhecimento reutilizável (spec-template)
```

Todos os comandos são prompts com `agent: agent` — executam em agent mode com acesso a ferramentas, invocados via `/comando` no chat.

---

## Replicabilidade

O **dev-looper** funciona para qualquer projeto com git. O que muda entre projetos é apenas o conteúdo de:

| Arquivo                          | O que adaptar                             |
| -------------------------------- | ----------------------------------------- |
| `copilot-instructions.md`        | Stack, padrões, comandos, armadilhas      |
| `prompts/code.prompt.md`          | Fases de implementação do stack           |

O restante (12+ arquivos) é copiado sem alteração.
