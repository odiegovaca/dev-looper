# dev-looper

Workflow de desenvolvimento com GitHub Copilot Agent Mode.

Fornece um conjunto de comandos `/` que guiam o desenvolvedor por um ciclo completo de desenvolvimento — da especificação ao PR de produção — com guardrails, padrões do projeto e auto-melhoria incorporados.

## Como o dev-looper é usado

É um **ponto de partida**, não uma dependência. Você instala uma vez, roda o `/setup`, e a partir daí a cópia é do seu projeto: adapte os prompts e os scripts ao que o seu time precisa, sem se preocupar em manter compatibilidade com este repositório.

Não existe atualização no lugar. Uma versão nova do dev-looper é um ponto de partida **novo** — para um projeto novo, ou para quem quiser reinstalar do zero e reaplicar as próprias adaptações. As [Releases](https://github.com/odiegovaca/dev-looper/releases) descrevem o que mudou entre uma versão e outra, e cada instalação registra no cabeçalho de `.github/prompts/README.md` de qual delas partiu.

---

## Pré-requisitos

- VS Code com extensão **GitHub Copilot** (com Agent Mode habilitado)
- Git configurado no projeto
- **`gh` CLI** — necessário para `/issue`, `/rc` e `/release` ([instalar](https://cli.github.com))

> O `/setup` confere o `gh` (instalado e autenticado) na inicialização e interrompe com mensagem clara se faltar. **Execute `/setup` antes de qualquer outro comando do workflow.**

> **Recomendação de modelo:** mantenha o seletor de modelo do Copilot em **Auto** — ele roteia automaticamente entre modelos de acordo com a complexidade de cada tarefa, o que combina bem com fases de granularidade variada (ex: `/spec` é mais leve que `/code`).

---

## Instalação (5 minutos)

### 1. Copiar os arquivos

```bash
.github/scripts/install.sh /caminho/do/seu/projeto
```

O script é idempotente: por arquivo, se o destino já existe e é diferente do que está sendo instalado, ele pula e reporta em vez de sobrescrever — use `--force` para sobrescrever mesmo assim. Isso protege o que o `/setup` preencheu (`bump-version.sh`, `coverage.sh`, `release-branches.sh` e `validate.sh`) caso o script rode uma segunda vez no mesmo projeto.

`--force` sobrescreve **inclusive** esses quatro arquivos, devolvendo-os aos placeholders `[DEFINIR]` — depois dele o projeto precisa rodar `/setup` de novo. Não o use para trazer mudanças de uma versão nova para um projeto já configurado.

> Alternativa sem o script: `cp -r .github/ /caminho/do/seu/projeto/.github/` — mas isso sobrescreve tudo cegamente, inclusive PRs/issues templates existentes.

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
4. Configurar `.github/scripts/bump-version.sh`, `coverage.sh`, `validate.sh` e `release-branches.sh` com os arquivos de versão, o comando de cobertura, os comandos de test/lint/build e as branches de release do stack detectado
5. Adaptar `.github/prompts/code.prompt.md` com os padrões do stack detectado

### 4. Validar

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
/test        Testes até a meta de cobertura do projeto
/review      Revisão crítica por criticidade
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

## Princípios

O dev-looper é desenhado como **fases disciplinadas em vez de um agente fazendo tudo num turno só**: cada comando (`/spec`, `/code`, `/test`, `/review`...) tem um escopo estreito e produz uma saída que o próximo comando consome. Isso mantém cada turno revisável — um diff de `/code` não se mistura com o de `/fix-review` — e permite interromper ou corrigir o rumo entre fases em vez de só no final.

`copilot-instructions.md` é a **memória central** do agente: qualquer padrão, comando ou armadilha que não estiver lá é reaprendido (ou inventado) do zero a cada sessão. Mantê-lo atualizado é o que faz o workflow escalar para projetos grandes e times com mais de uma pessoa usando os mesmos comandos.

`/lesson` é o **mecanismo de melhoria contínua**: em vez de corrigir o agente manualmente toda vez que ele repete um erro, `/lesson` formaliza a correção como instrução permanente em `copilot-instructions.md` ou num prompt específico — o sistema aprende com o uso real do time.

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
- **`rc.prompt.md`**: Ajustar se o projeto não usar versionamento RC.
- Arquivos de versão e branches de produção/integração **não** ficam em prompt: são o `VERSION_FILES` do `bump-version.sh` e o `PROD_BRANCH`/`INTEGRATION_BRANCH` do `release-branches.sh`, preenchidos pelo `/setup`.

Os demais prompts buscam padrões e comandos em `copilot-instructions.md` — nenhum precisa de alteração manual após o `/setup`.

---

## Arquitetura

```
.github/
  copilot-instructions.md      ← Conhecimento do projeto (gerado por /setup)
  prompts/                     ← Todos os comandos / acessíveis no chat
  scripts/                     ← Versão, cobertura, testes, PRs e branches, calculados por script em vez de recalculados em prosa
```

Todos os comandos são prompts com `agent: agent` — executam em agent mode com acesso a ferramentas, invocados via `/comando` no chat.

---

## Replicabilidade

O **dev-looper** funciona para qualquer projeto com git. O que muda entre projetos é apenas o conteúdo de:

| Arquivo                          | O que adaptar                             |
| -------------------------------- | ----------------------------------------- |
| `copilot-instructions.md`        | Stack, padrões, comandos, armadilhas      |
| `prompts/code.prompt.md`          | Fases de implementação do stack           |
| `scripts/bump-version.sh`         | Lista `VERSION_FILES` do projeto          |
| `scripts/coverage.sh`             | Comando de cobertura do stack             |
| `scripts/validate.sh`             | Comandos de test/lint/build do stack      |
| `scripts/release-branches.sh`     | `PROD_BRANCH`/`INTEGRATION_BRANCH` do projeto |

O restante (10+ arquivos) é copiado sem alteração.
