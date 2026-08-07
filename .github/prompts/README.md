# Prompts — Guia Rápido

Prompts aceitam parâmetros após o comando (ex: `/rc patch`, `/test 85`) — ver tabela em [Parâmetros](#parâmetros) abaixo.

## Fluxo Completo (Nova Funcionalidade)

1. `/spec` → Especificação funcional
2. `/issue` → Issue GitHub
3. `/code` → Código + testes básicos (happy path + erros esperados)
   - `/test` → _se cobertura abaixo da meta após `/code`_
4. `/review` → Revisão de qualidade por criticidade
   - `/fix-review [alvo]` → _se houver problemas critical ou high a tratar_
5. `/rc` → PR → branch de integração (versão RC)
6. `/release` → PR → produção (versão estável)

## Comandos Auxiliares

- `/setup` → Bootstrap inicial — apenas uma vez por projeto
- `/status` → Snapshot: branch, versão, cobertura, último review, próximo passo
- `/lesson [lição]` → Formalizar correção em instrução permanente — use logo após corrigir algo manualmente, antes que a regra se perca

## Parâmetros

Fonte da verdade é o `argument-hint` de cada `.prompt.md` — atualize aqui junto se ele mudar.

| Comando       | Parâmetro                                                                  | Exemplo                                          |
| ------------- | --------------------------------------------------------------------------- | ------------------------------------------------- |
| `/spec`       | Descrição da funcionalidade ou caminho da spec para refinar (opcional)      | `/spec Checkout via Pix`                          |
| `/issue`      | Caminho da spec (opcional, usa a spec aprovada mais recente se omitido)     | `/issue docs/issues/spec-checkout-pix.md`         |
| `/code`       | Caminho da spec ou descrição da funcionalidade                              | `/code docs/issues/spec-checkout-pix.md`          |
| `/test`       | Meta de cobertura em % (opcional, padrão 80)                                | `/test 85`                                        |
| `/review`     | Nome da branch de integração, sem prefixo `origin/` (opcional, padrão `develop`) | `/review develop`                             |
| `/fix-review` | Número(s), `todos`, `critical` ou `high`                                    | `/fix-review 1 2 5`, `/fix-review critical`       |
| `/rc`         | Tipo de versão: `patch`, `minor` ou `major` (opcional, inferido se omitido) | `/rc patch`                                       |
| `/release`    | Versão de release (opcional, deriva da RC atual se omitido)                 | `/release 2.5.0`                                  |
| `/setup`      | Descrição do projeto (opcional, usada só se não houver README)              | —                                                  |
| `/status`     | Nenhum                                                                       | —                                                  |
| `/lesson`     | Descrição do aprendizado (opcional, pergunta se omitido)                    | `/lesson Controllers void não devem ter @ApiResponse tipado` |

## Arquitetura

- **Todos os comandos são prompts** com `agent: agent` — executam em agent mode com acesso a ferramentas, invocados via `/comando`
- **Tool restrictions**: cada prompt tem `tools:` restrito ao mínimo necessário
- **copilot-instructions.md**: "memória" do projeto — lida em toda sessão

## Personalização

Tudo o que é projeto-específico fica em `.github/copilot-instructions.md`. Os prompts buscam padrões, comandos e convenções nesse arquivo. Mantenha-o atualizado com `/lesson`.
