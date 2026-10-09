# dev-looper

Workflow de desenvolvimento com GitHub Copilot Agent Mode ou Claude Code.

Fornece um conjunto de comandos `/` que guiam o desenvolvedor por um ciclo completo de desenvolvimento — da especificação ao PR de produção — com guardrails, padrões do projeto e auto-melhoria incorporados.

## Como o dev-looper é usado

É um **ponto de partida**, não uma dependência. Você instala uma vez, roda o `/dl-setup`, e a partir daí a cópia é do seu projeto: adapte os prompts e os scripts ao que o seu time precisa, sem se preocupar em manter compatibilidade com este repositório.

Não existe atualização no lugar. Uma versão nova do dev-looper é um ponto de partida **novo** — para um projeto novo, ou para quem quiser reinstalar do zero e reaplicar as próprias adaptações. As [Releases](https://github.com/odiegovaca/dev-looper/releases) descrevem o que mudou entre uma versão e outra, e cada instalação registra no cabeçalho do guia instalado (`.github/prompts/README.md` no Copilot, `.claude/dev-looper.md` no Claude Code) de qual delas partiu.

---

## Pré-requisitos

- Um dos agentes: VS Code com extensão **GitHub Copilot** (com Agent Mode habilitado) ou **Claude Code**
- Git configurado no projeto
- **`gh` CLI** — necessário para `/dl-issue`, `/dl-rc` e `/dl-release` ([instalar](https://cli.github.com))

> O `/dl-setup` confere o `gh` (instalado e autenticado) na inicialização e interrompe com mensagem clara se faltar. **Execute `/dl-setup` antes de qualquer outro comando do workflow.**

> **Recomendação de modelo (Copilot):** mantenha o seletor de modelo do Copilot em **Auto** — ele roteia automaticamente entre modelos de acordo com a complexidade de cada tarefa, o que combina bem com fases de granularidade variada (ex: `/dl-spec` é mais leve que `/dl-code`).

---

## Instalação (5 minutos)

### 1. Copiar os arquivos

Na raiz do dev-looper:

```bash
./install.sh /caminho/do/seu/projeto                  # GitHub Copilot (padrão)
./install.sh /caminho/do/seu/projeto --agent claude   # Claude Code
```

O conteúdo dos comandos é o mesmo para os dois agentes; o que muda é onde cada arquivo vai e o cabeçalho que o agente espera:

| | Copilot | Claude Code |
| --- | --- | --- |
| Comandos `/` | `.github/prompts/*.prompt.md` | `.claude/commands/*.md` |
| Guia do fluxo | `.github/prompts/README.md` | `.claude/dev-looper.md` |
| Instruções do projeto (geradas pelo `/dl-setup`) | `AGENTS.md`, lido pelo VS Code por padrão | `AGENTS.md`, carregado pelo `@AGENTS.md` do `CLAUDE.md` |
| Scripts | `.github/scripts/` | `.claude/scripts/` |

O arquivo de instruções é o mesmo `AGENTS.md` nos dois agentes, então um time com gente nos dois usa as mesmas regras. No Copilot, o VS Code o lê por padrão (configuração `chat.useAgentsMdFile`, ligada de fábrica). No Claude Code, o `CLAUDE.md` só é criado se o projeto ainda não tiver um — se já tiver, acrescente a linha `@AGENTS.md` a ele (o script avisa); o Claude Code não lê o `AGENTS.md` sozinho.

O script é idempotente: por arquivo, se o destino já existe e é diferente do que está sendo instalado, ele pula e reporta em vez de sobrescrever — use `--force` para sobrescrever mesmo assim. Isso protege o que o `/dl-setup` preencheu (`bump-version.sh`, `coverage.sh`, `release-branches.sh` e `validate.sh`) caso o script rode uma segunda vez no mesmo projeto.

`--force` sobrescreve **inclusive** esses quatro arquivos, devolvendo-os aos placeholders `[DEFINIR]` — depois dele o projeto precisa rodar `/dl-setup` de novo. Não o use para trazer mudanças de uma versão nova para um projeto já configurado.

Não há alternativa de cópia manual: os arquivos de `core/` têm marcadores que só o `install.sh` preenche.

### 2. Recarregar o agente

**Copilot:** após copiar os arquivos, recarregue a janela para que o Copilot reconheça os novos comandos `/`:

> `Ctrl+Shift+P` → **Developer: Reload Window**

> Os arquivos `.prompt.md` são indexados na abertura do workspace — sem reload, os comandos `/` não aparecem no chat.

**Claude Code:** abra uma sessão nova no diretório do projeto.

### 3. Bootstrap automático

Abra o projeto e execute no chat do agente:

```
/dl-setup
```

O agente vai:

1. Detectar stack (linguagem, framework, banco, CI/CD)
2. Fazer perguntas pontuais sobre o que não conseguir inferir
3. Gerar o arquivo de instruções do projeto (`AGENTS.md`)
4. Configurar, na pasta de scripts, `bump-version.sh`, `coverage.sh`, `validate.sh` e `release-branches.sh` com os arquivos de versão, o comando de cobertura, os comandos de test/lint/build e as branches de release do stack detectado
5. Adaptar o prompt do `/dl-code` com os padrões do stack detectado

### 4. Validar

```
/dl-status
```

Deve mostrar branch atual, versão e sugerir próximo passo.

---

## O Workflow

```
/dl-spec      Escrever especificação funcional
/dl-issue     Criar issue GitHub da spec
/dl-code      Gerar código seguindo a spec e padrões do projeto
/dl-test      Testes até a meta de cobertura do projeto
/dl-review    Revisão crítica priorizada por severidade
/dl-fix       Aplicar correções do code review
/dl-rc        PR → branch de integração (com versionamento RC)
/dl-release   PR → produção (versão estável)
```

**Comandos auxiliares:**

```
/dl-status    Snapshot: branch, versão, cobertura, último review
/dl-lesson    Formalizar correção em instrução permanente
```

O prefixo `dl-` evita colisão com os comandos que os próprios agentes já trazem — o Claude Code, por exemplo, tem `/review` e `/status`.

**O ciclo review → fix:**

- O primeiro `/dl-review` da feature é **completo**: tudo desde o merge-base com a branch de integração. O relatório registra o commit que revisou.
- Os seguintes são **incrementais**: leem só o que mudou desde esse commit (no ciclo normal, o fix), conferem se cada correção aplicada cumpre o **Critério** do problema e só abrem problema para o que está no diff. Algo grave que já estava fora do diff vai para a seção "Fora do escopo", que não conta para o veredito e não reabre o ciclo. `/dl-review --completo` revisa a branch inteira de novo.
- **Teto de 2 rodadas:** se o review da segunda rodada de `/dl-fix` ainda tiver bloqueantes, o próximo passo deixa de ser outro `/dl-fix` e vira `⛔ Teto`: parar e olhar a spec ou o desenho, não mais uma correção.
- **O PR do `/dl-rc` carrega o ciclo** (`pr-report.sh`), para quem aprova ler o resumo em vez do diff linha por linha: as dispensas do agente como perguntas, os achados fora do escopo, o que ficou sem corrigir em todas as rodadas, a cobertura abaixo da meta e uma linha por review. Os achados vão inteiros, porque `docs/reviews/` pode não estar versionado. A spec não vai: ela é o corpo da issue, que o PR fecha. Seção vazia não aparece.

---

## Princípios

O dev-looper é desenhado como **fases disciplinadas em vez de um agente fazendo tudo num turno só**: cada comando (`/dl-spec`, `/dl-code`, `/dl-test`, `/dl-review`...) tem um escopo estreito e produz uma saída que o próximo comando consome. Isso mantém cada turno revisável — um diff de `/dl-code` não se mistura com o de `/dl-fix` — e permite interromper ou corrigir o rumo entre fases em vez de só no final.

O `AGENTS.md` é a **memória central** do agente: qualquer padrão, comando ou armadilha que não estiver lá é reaprendido (ou inventado) do zero a cada sessão. Mantê-lo atualizado é o que faz o workflow escalar para projetos grandes e times com mais de uma pessoa usando os mesmos comandos.

`/dl-lesson` é o **mecanismo de melhoria contínua**: em vez de corrigir o agente manualmente toda vez que ele repete um erro, `/dl-lesson` formaliza a correção como instrução permanente no `AGENTS.md` ou num prompt específico — o sistema aprende com o uso real do time.

---

## Customização

### O arquivo central: `AGENTS.md`

Esse arquivo é o "onboarding do agente" — ele aprende o projeto lendo esse arquivo no início de cada sessão. Mantenha-o atualizado com:

- Stack e versões
- Padrões de código (exception handling, logging, auth)
- Comandos de desenvolvimento (`test`, `build`, `lint`)
- Armadilhas comuns (Common Pitfalls)
- Padrões de banco de dados

Use `/dl-lesson` após qualquer correção manual para manter esse arquivo crescendo automaticamente.

### Adaptar os prompts

- **Prompt do `/dl-code`**: Fases de implementação específicas do stack. Gerado automaticamente pelo `/dl-setup` mas pode ser ajustado manualmente.
- **Prompt do `/dl-rc`**: Ajustar se o projeto não usar versionamento RC.
- Arquivos de versão e branches de produção/integração **não** ficam em prompt: são o `VERSION_FILES` do `bump-version.sh` e o `PROD_BRANCH`/`INTEGRATION_BRANCH` do `release-branches.sh`, preenchidos pelo `/dl-setup`.

Os demais prompts buscam padrões e comandos no `AGENTS.md` — nenhum precisa de alteração manual após o `/dl-setup`.

---

## Modo autônomo (opcional)

Desligado por padrão: o fluxo é o interativo descrito acima, com os checkpoints de sempre. O modo autônomo existe para rodar as fases sem ninguém no chat (um orquestrador chamando uma fase depois da outra).

O modo vem do `autonomous-mode.sh`, na pasta de scripts, que os prompts consultam na hora. Com o modo ligado, ele imprime também as regras que valem em toda fase. O que muda em cada fase fica no script de fechamento dela (o `code-finalize.sh` do `/dl-code`, por exemplo).

- **Para uma execução:** `DEV_LOOPER_AUTONOMOUS=1` no ambiente liga o modo só para aquela execução, por cima do padrão do projeto (`0` desliga). É o caminho de um orquestrador.
- **Para o projeto:** `AUTONOMOUS=true` no script muda o padrão de todo mundo que usa o projeto.

O `/dl-status` mostra o modo em uso. Com o modo ligado:

- O `/dl-code` faz o commit no fim, em vez de parar no checkpoint de revisão. Onde perguntaria ou pediria confirmação (spec ainda em rascunho, issue sem número), ele para sem commit, e a resposta começa com `⛔ Parado: <motivo>`.
- O `/dl-test` faz o commit no fim (`test-finalize.sh`). Meta de cobertura não atingida não para a fase: o commit sai com a cobertura e a meta na mensagem.
- O `/dl-fix` faz um commit por rodada (`fix-review-finalize.sh`), separado dos outros, e não sugere próximo passo: o orquestrador decide pelo status pós-fix. Sem argumento, ele para sem commit. Correção contestada não para a fase: vira dispensa com o motivo marcado como do agente (`agente — exige decisão: <proposta>` ou `agente — não é problema: <por quê>`), que chega ao usuário no PR.

### Orquestrador

O `orchestrate.sh`, na pasta de scripts, leva uma issue da spec aprovada até o PR sem ninguém no chat. Os gates humanos ficam nas pontas: você aprova a spec na entrada e lê o PR na saída.

```bash
.claude/scripts/orchestrate.sh docs/issues/spec-AAAA-MM-DD-<id>.md
```

- **Entrada:** spec com `Status` aprovado (ou `Issue criada`), sem Questões em Aberto e com issue vinculada; árvore limpa; e a branch de integração igual à do `origin`. A esteira cria `feature/<N>-<id>` a partir dela.
- **Fases:** `/dl-code` → `/dl-test` → `/dl-review` → (`/dl-fix` → `/dl-review`)… → `/dl-rc`, cada uma numa sessão nova do agente (`run-phase.sh`), no modo autônomo. Depois de cada review ou fix, a próxima fase sai do `next-step.sh`, o mesmo do `/dl-status`, com o teto de rodadas.
- **Paradas:** a fase responde `⛔ Parado`; a sessão falha; sobra mudança sem commit; a fase troca de branch; o review não gera relatório; a mesma fase vem duas vezes seguidas (um fix que não mudou o estado); o teto de rodadas; ou o `/dl-rc` termina sem PR aberto. A mensagem final traz o comando de retomada (`--desde code|test|review|rc`, de dentro da branch da issue).
- **Acompanhamento:** enquanto a fase roda, cada ação do agente sai numa linha com a hora (`· 20:31 Bash .claude/scripts/validate.sh lint build test`). Sem elas, uma fase de meia hora parece travada.
- **Log:** em `.git/dev-looper/runs/<N>-<data>/`, uma linha por fase em `run.md` e, ao lado, a resposta inteira de cada uma, com as ações dela. Fica dentro do `.git` para nunca entrar num commit.
- **Agente:** só o Claude Code por enquanto (`claude -p`, com `jq`). As fases rodam com edição liberada e com os scripts do fluxo, `git` e `gh` sem confirmação. Comandos do projeto que o agente roda soltos (um teste isolado, por exemplo) vão nas permissões do `.claude/settings.json` do projeto. Ferramenta negada aparece no log como `⚠️ negado`.

---

## Arquitetura

Neste repositório:

```
core/
  prompts/                     ← Corpo de cada comando /, com frontmatter neutro
  guide.md                     ← Guia do fluxo instalado no projeto
  instructions.template.md     ← Semente do arquivo de instruções, consumida pelo /dl-setup
  scripts/                     ← Versão, cobertura, testes, PRs e branches, calculados por script em vez de recalculados em prosa
adapters/
  copilot.sh, claude.sh        ← Destino de cada arquivo, frontmatter e valor de cada {{MARCADOR}} por agente
install.sh                     ← Instala core/ no projeto pelo adaptador do --agent
```

O texto que só faz sentido para um agente (onde ficam os prompts e o guia, nome da ferramenta de TODO) fica em `core/` como `{{MARCADOR}}`, e cada adaptador dá o valor. Mudança de comportamento vai em `core/`; um adaptador só muda quando o agente muda o que espera.

No projeto, os comandos executam com acesso a ferramentas (agent mode no Copilot) e são invocados via `/comando` no chat.

---

## Replicabilidade

O **dev-looper** funciona para qualquer projeto com git. O que muda entre projetos é apenas o conteúdo de:

| Arquivo                          | O que adaptar                                 |
| -------------------------------- | --------------------------------------------- |
| `AGENTS.md`                      | Stack, padrões, comandos, armadilhas          |
| Prompt do `/dl-code`                | Fases de implementação do stack               |
| `scripts/bump-version.sh`        | Lista `VERSION_FILES` do projeto              |
| `scripts/coverage.sh`            | Comando de cobertura do stack                 |
| `scripts/validate.sh`            | Comandos de test/lint/build do stack          |
| `scripts/release-branches.sh`    | `PROD_BRANCH`/`INTEGRATION_BRANCH` do projeto |
| `scripts/autonomous-mode.sh`     | Opcional: `AUTONOMOUS=true` liga o modo autônomo como padrão |

O restante (10+ arquivos) é copiado sem alteração.
