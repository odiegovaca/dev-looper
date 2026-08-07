---
description: Aplicar correções do último code review por número, severidade ou todas
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Número(s), 'todos', 'critical' ou 'high' (ex: /fix-review 3, /fix-review 1 2 5, /fix-review critical)"
---

# /fix-review - Aplicar Correções do Code Review

Aplique correções identificadas no último relatório de code review.

**Arquivos Protegidos** (ver `copilot-instructions.md`): se uma correção sugerida no relatório apontar para `.github/prompts/*.md` ou `copilot-instructions.md`, sinalizar ao usuário e pular o item.

## Processo

### 1 — Localizar Relatório

```bash
REPORT=$(.github/scripts/latest-review.sh)
```

### 2 — Identificar Problemas

Selecionar os problemas em `$REPORT` conforme o argumento:

- **Número(s)** (ex: `3`, `1 2 5`): problemas com esses números; inexistente no relatório → avisar e ignorar, sem interromper os demais
- **Severidade(s)** (`critical`, `high`, case-insensitive e combináveis, ex: `critical high`): todos os problemas dessa(s) severidade(s)
- **`todos`**: todos os problemas
- **Sem argumento**: perguntar ao usuário quais deseja corrigir

Se mais de um problema for selecionado, montar `manage_todo_list` com um item por problema (número + descrição breve) antes de aplicar as correções.

### 3 — Aplicar Correções

Para cada problema:

1. Ler o arquivo mencionado (arquivo:linha do relatório)
2. Entender o problema e a solução sugerida; se parecer errada, informar e propor alternativa em vez de aplicar
3. Aplicar a correção seguindo os padrões de `copilot-instructions.md`, sem alterar código não relacionado ao problema
4. Verificar contra a seção "Padrões Obrigatórios" de `copilot-instructions.md` e confirmar que não quebra testes existentes
5. Marcar como concluído no TODO, se houver

### 4 — Validar

```bash
.github/scripts/validate.sh lint build test
```

Se falhar por causa de uma correção aplicada, corrigir antes de prosseguir (máx 3 iterações); se persistir, parar e reportar ao usuário em vez de deixar a falha para o `/test`.

### 5 — Confirmar

```
✅ X correções aplicadas, lint/build/test OK.
   Pendências: [um por linha com o motivo — número inexistente, arquivo protegido, severidade não incluída — ou "nenhuma"]
   Sugestão: git commit "fix: aplica correções do review #{N}" como checkpoint, depois /rc. Se houver pendências, `/fix-review` novamente para elas antes.
```

### 6 — Listar Lições para `/lesson`

No fim do `/fix-review`, sempre incluir uma seção de aprendizados para prevenir recorrência.

Formato — bloco estruturado por lição, sem prosa livre:

```markdown
## 📚 Lições para /lesson

- problema: #N [título curto]
  regra_proposta: [texto pronto para colar como argumento de /lesson]
  destino: [arquivo — mesmo critério de classificação do passo 2 de /lesson]
```

Regras:

- 1 a 6 lições por execução
- Lições específicas e acionáveis
- Se não houver correção aplicada: `Nenhuma lição nova identificada nesta execução.`
