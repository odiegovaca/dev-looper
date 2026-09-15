# Prompts — Guia Rápido

> Fluxo do [dev-looper](https://github.com/odiegovaca/dev-looper), versão de origem `__DEV_LOOPER_VERSION__`.

## Fluxo Completo (Nova Funcionalidade)

1. `/spec` → Especificação funcional
2. `/issue` → Issue GitHub
3. `/code` → Código + testes básicos (happy path + erros esperados)
   - `/test` → _se cobertura abaixo da meta após `/code`_
4. `/review` → Revisão de qualidade crítica por nível de severidade
   - `/fix-review [alvo]` → _se houver problemas a tratar; critical e high bloqueiam o `/rc`_
5. `/rc` → PR → branch de integração (versão RC)
6. `/release` → PR → produção (versão estável)

## Comandos Auxiliares

- `/setup` → Bootstrap inicial — apenas uma vez por projeto
- `/status` → Snapshot: branch, versão, cobertura, último review, próximo passo
- `/lesson [lição]` → Formalizar correção em instrução permanente — use logo após corrigir algo manualmente, antes que a regra se perca

## Parâmetros

Cada prompt declara os seus no `argument-hint` do frontmatter:

```bash
grep -H '^argument-hint:' .github/prompts/*.prompt.md
```

## Personalização

Tudo o que é projeto-específico fica em `.github/copilot-instructions.md`. Os prompts buscam padrões, comandos e convenções nesse arquivo. Mantenha-o atualizado com `/lesson`.
