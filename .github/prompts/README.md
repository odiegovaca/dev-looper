# Prompts — Guia Rápido

Prompts aceitam parâmetros após o comando (ex: `/rc patch`, `/test 85`).

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
- `/lesson [lição]` → Formalizar correção em instrução permanente

## Arquitetura

- **Todos os comandos são prompts** com `agent: agent` — executam em agent mode com acesso a ferramentas, invocados via `/comando`
- **Tool restrictions**: cada prompt tem `tools:` restrito ao mínimo necessário
- **copilot-instructions.md**: "memória" do projeto — lida em toda sessão

## Personalização

Tudo o que é projeto-específico fica em `.github/copilot-instructions.md`. Os prompts buscam padrões, comandos e convenções nesse arquivo. Mantenha-o atualizado com `/lesson`.
