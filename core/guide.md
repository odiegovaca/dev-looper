# Prompts — Guia Rápido

> Fluxo do [dev-looper](https://github.com/odiegovaca/dev-looper), versão de origem `{{VERSION}}`.

## Fluxo Completo (Nova Funcionalidade)

1. `/dl-spec` → Especificação funcional
2. `/dl-issue` → Issue GitHub
3. `/dl-code` → Código + testes básicos (happy path + erros esperados)
   - `/dl-test` → _se cobertura abaixo da meta após `/dl-code`_
4. `/dl-review` → Revisão de qualidade crítica por nível de severidade
   - `/dl-fix [alvo]` → _se houver problemas a tratar; critical e high bloqueiam o `/dl-rc`_
5. `/dl-rc` → PR → branch de integração (versão RC)
6. `/dl-release` → PR → produção (versão estável)

## Comandos Auxiliares

- `/dl-setup` → Bootstrap inicial — apenas uma vez por projeto
- `/dl-status` → Snapshot: branch, versão, cobertura, último review, próximo passo
- `/dl-lesson [lição]` → Formalizar correção em instrução permanente — use logo após corrigir algo manualmente, antes que a regra se perca

## Parâmetros

Cada prompt declara os seus no `argument-hint` do frontmatter:

```bash
grep -H '^argument-hint:' {{PROMPTS_DIR}}/*{{PROMPT_EXT}}
```

## Personalização

Tudo o que é projeto-específico fica em `AGENTS.md`. Os prompts buscam padrões, comandos e convenções nesse arquivo. Mantenha-o atualizado com `/dl-lesson`.
