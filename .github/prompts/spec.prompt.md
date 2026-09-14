---
description: Criar especificação de funcionalidade em linguagem natural
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Descrição da funcionalidade ou caminho da spec para refinar"
---

# /spec - Criar Especificação

A spec é legível por não-técnicos: linguagem natural, sem código.

## Processo

### 1 — Resolver o Arquivo

```bash
.github/scripts/spec-path.sh "$ARGUMENTS"
```

- `MODO=nova` → escrever o arquivo do zero, com o template abaixo
- `MODO=refinamento` → ler a spec inteira antes de alterar
- `MODO=conflito` → perguntar ao usuário qual das `CANDIDATAS` refinar

**Se veio `MODO=nova` mas o usuário falava de uma spec que já existe**, não crie: diga que não encontrou, liste as de `docs/issues/` e confirme antes de seguir. O script só compara identificadores — quem lê a intenção do pedido é você.

O campo `**Data**` recebe `DATA_CAMPO` nos dois modos. O nome do arquivo nunca muda num refinamento.

### 2 — Escrever

**Nova**: analisar problema, restrições, integrações e regras de negócio; classificar o **Tipo** (`feature` se a capacidade não existia, `improvement` se muda algo que já existe); preencher o template.

**Refinamento**: adicionar requisitos e responder questões em aberto — cada resposta sai da seção "Questões em Aberto" e é incorporada na seção correta, e o `**Status**` acompanha se mudou. Se o `Status` for `Aprovada` ou `Issue criada`, confirmar com o usuário antes de alterar requisito, regra de negócio ou critério de aceite já existente: a mudança pode invalidar issue e código já feitos a partir da spec.

### 3 — Apresentar

```bash
.github/scripts/spec-status.sh <arquivo> [nova|refinamento]
```

Acrescentar um resumo do que mudou. Nunca editar a issue na mão — é o `/issue` que sincroniza.

## Regras

❌ **NUNCA**: código fonte, termos técnicos sem explicação, ambiguidades, suposições não documentadas

✅ **SEMPRE**:

- Frases curtas (máximo 2 linhas por item)
- Voz ativa: "Sistema valida campo X", não "O campo X deve ser validado"
- Exemplos concretos de valores, formatos e fluxos
- Questões em aberto numeradas (**Q1**, **Q2**)
- Critérios de aceite como checkboxes testáveis, não afirmações genéricas
- Omitir seções vazias — sem integrações, não inclua a seção

## Template

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

## Validações

- Campo X: obrigatório, formato Y
- Campo Z: mín N, máx M

## Integrações (se houver)

- **Sistema X**: para [propósito], com formato da requisição/resposta

## Critérios de Aceitação

- [ ] Sistema permite [ação] quando [condição específica]
- [ ] Validação rejeita [entrada inválida] com mensagem "[mensagem exata]"
- [ ] Testes cobrem [cenário principal] e [cenário de erro]

## Questões em Aberto (se houver)

- ❓ **Q1**: [Questão que precisa de resposta antes de implementar]

## Referências (se houver)

- [ADR ou documento relacionado]
```

O `Status` anda `Rascunho` → `Em Revisão` → `Aprovada`; `Issue criada` é gravado pelo `/issue`, não aqui.
