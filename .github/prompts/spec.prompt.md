---
description: Criar especificação de funcionalidade em linguagem natural
agent: agent
tools: [read, edit, search]
argument-hint: "Descrição da funcionalidade ou caminho da spec para refinar"
---

# /spec - Criar Especificação

Analista de sistemas especializado em transformar requisitos em **especificações estruturadas em linguagem natural**.

## Task

Criar ou refinar especificação compreensível sem código, legível por não-técnicos.

### Modo 1: Nova Especificação

1. **Analise**: Problema, funcionalidade, restrições, integrações, regras de negócio
2. **Estruture**: seguindo o template e convenções da seção Template abaixo
3. **Crie**: `docs/issues/spec-[identificador-kebab-case].md`
4. **Apresente**: Resumo, questões em aberto, caminho do arquivo

### Modo 2: Refinar Especificação

Quando usuário menciona arquivo existente:

1. **Busque** em `docs/issues/`
2. **Leia** especificação completa
3. **Aplique mudanças**: Adicionar requisitos, responder questões em aberto
4. **Ao responder questões**: remova da seção "Questões em Aberto" e incorpore na seção correta
5. **Atualize**: Data, status se mudou

## Regras

✅ **SEMPRE**: Voz ativa, específico, exemplos concretos, parágrafos curtos, questões em aberto listadas

❌ **NUNCA**: Código fonte, termos técnicos sem explicação, ambiguidades, suposições não documentadas

## Próximos Passos

Ao concluir, sugerir:

```
✅ Spec criada. Próximo passo: revise as Questões em Aberto.
   Quando aprovada: /issue para criar a issue GitHub.
```

---

## Template

Template e convenções para especificações de funcionalidade.

### Template Completo

```markdown
# [Título Descritivo]

**Data**: DD/MM/YYYY  
**Status**: `Rascunho | Em Revisão | Aprovado`

## O Que Será Feito

Descrição direta (2-4 parágrafos). Foque no "o quê" e "por quê", não no "como".

## Requisitos

1. O sistema deve...
2. O sistema deve...

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

- [ ] Sistema permite [ação]
- [ ] Validações impedem [comportamento indesejado]
- [ ] Testes cobrem cenários principais

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
| `Aprovado`     | Pronto para criar issue e implementar (`/issue`)     |
| `Issue criada` | Issue GitHub vinculada, desenvolvimento pode iniciar |

### Princípios

✅ Frases curtas (máximo 2 linhas por item)  
✅ Voz ativa: "Sistema valida campo X" vs "O campo X deve ser validado"  
✅ Exemplos concretos de valores, formatos e fluxos  
✅ Numerar questões em aberto (**Q1**, **Q2**) para referência fácil  
✅ Omitir seções vazias — sem integrações? não inclua a seção  
✅ Critérios de aceite como checkboxes testáveis, não afirmações genéricas
