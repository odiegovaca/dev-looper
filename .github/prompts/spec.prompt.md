---
description: Criar especificação de funcionalidade em linguagem natural
agent: agent
tools: [read, edit, search]
argument-hint: "Descrição da funcionalidade ou caminho da spec para refinar"
---

# /spec - Criar Especificação

Analista de sistemas especializado em transformar requisitos em **especificações estruturadas em linguagem natural**: criar ou refinar especificação compreensível sem código, legível por não-técnicos.

## Processo

### Modo 1 — Nova Especificação

1. **Analise**: Problema, funcionalidade, restrições, integrações, regras de negócio
2. **Classifique o Tipo**: `feature` se a capacidade não existia antes, `improvement` se muda/melhora algo que já existe
3. **Estruture**: seguindo o template e convenções da seção Template abaixo
4. **Derive o identificador**: kebab-case a partir do título (minúsculas, sem acentos, espaços e símbolos viram `-`)
5. **Verifique conflito**: se `docs/issues/spec-[identificador].md` já existir, avise o usuário e pergunte se quer outro identificador ou tratar como refinamento (Modo 2)
6. **Crie**: `docs/issues/spec-[identificador-kebab-case].md`
7. **Apresente**: Resumo, questões em aberto, caminho do arquivo

### Modo 2 — Refinar Especificação

Quando usuário menciona arquivo, identificador ou descrição de funcionalidade existente:

1. **Busque** em `docs/issues/`. Não encontrou spec correspondente? Informe e sugira `/spec` para criar uma nova
2. **Leia** especificação completa
3. **Se status for `Aprovada` ou `Issue criada`**: antes de alterar requisitos, regras de negócio ou critérios de aceite já existentes, confirme com o usuário — a mudança pode invalidar issue/código já criados a partir da spec
4. **Aplique mudanças**: Adicionar requisitos, responder questões em aberto
5. **Ao responder questões**: remova da seção "Questões em Aberto" e incorpore na seção correta
6. **Atualize**: Data, status se mudou

## Regras

✅ **SEMPRE**: Voz ativa, específico, exemplos concretos, parágrafos curtos, questões em aberto listadas

❌ **NUNCA**: Código fonte, termos técnicos sem explicação, ambiguidades, suposições não documentadas

## Próximos Passos

Ao concluir, adapte a sugestão ao resultado:

- **Spec criada/atualizada com questões em aberto pendentes**:
  ```
  ✅ Spec [criada|atualizada]. Próximo passo: revise as Questões em Aberto.
     Quando aprovada: /issue para criar a issue GitHub.
  ```
- **Sem questões pendentes e status `Aprovada`**:
  ```
  ✅ Spec aprovada, sem questões pendentes. Próximo passo: /issue para criar a issue GitHub.
  ```
- **Refinamento que só respondeu questões, sem mudar status**:
  ```
  ✅ Questão(ões) respondida(s). Spec segue como [status atual].
  ```

## Template

Template e convenções para especificações de funcionalidade.

### Template Completo

```markdown
# [Título Descritivo]

**Data**: DD/MM/YYYY  
**Status**: `Rascunho | Em Revisão | Aprovada`  
**Tipo**: `feature | improvement`

## O Que Será Feito

Descrição direta (2-4 parágrafos). Foque no "o quê" e "por quê", não no "como".

## Requisitos

1. O sistema deve...
2. O sistema deve...

## Fora de Escopo (se houver)

- [O que não será feito nesta funcionalidade, para evitar ambiguidade]

## Regras de Negócio

- **RN01**: [Regra] — [Justificativa]
- **RN02**: [Regra] — [Justificativa]

## Validações

- Campo X: obrigatório, formato Y
- Campo Z: mín N, máx M

## Integrações (se houver)

- **Sistema X**: para [propósito]
- Especificar formato da requisição/resposta de cada integração

## Critérios de Aceitação

- [ ] Sistema permite [ação] quando [condição específica]
- [ ] Validação rejeita [entrada inválida] com mensagem "[mensagem exata]"
- [ ] Testes cobrem [cenário principal] e [cenário de erro]

## Questões em Aberto (se houver)

- ❓ **Q1**: [Questão que precisa de resposta antes de implementar]
- ❓ **Q2**: [Questão]

## Referências (se houver)

- [ADR ou documento relacionado]
```

### Nomenclatura de Arquivo

Padrão: `docs/issues/spec-[identificador-kebab-case].md`

Exemplos:

- `spec-agendamento-mensagens.md`
- `spec-relatorio-vendas.md`
- `spec-integracao-pagamentos.md`

### Status Válidos

| Status         | Significado                                          |
| -------------- | ---------------------------------------------------- |
| `Rascunho`     | Em elaboração                                        |
| `Em Revisão`   | Aguardando aprovação de stakeholder                  |
| `Aprovada`     | Pronto para criar issue e implementar (`/issue`)     |
| `Issue criada` | Issue GitHub vinculada, desenvolvimento pode iniciar |

### Princípios

✅ Frases curtas (máximo 2 linhas por item)  
✅ Voz ativa: "Sistema valida campo X" vs "O campo X deve ser validado"  
✅ Exemplos concretos de valores, formatos e fluxos  
✅ Numerar questões em aberto (**Q1**, **Q2**) para referência fácil  
✅ Omitir seções vazias — sem integrações? não inclua a seção  
✅ Critérios de aceite como checkboxes testáveis, não afirmações genéricas
