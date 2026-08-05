---
description: Aplicar correções do último code review por número, severidade ou todas
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Número(s), 'todos', 'critical' ou 'high' (ex: /fix-review 3, /fix-review 1 2 5, /fix-review critical)"
---

# /fix-review - Aplicar Correções do Code Review

Aplique correções identificadas no último relatório de code review.

## Processo

### 1. Localizar Relatório

```bash
ls -t docs/reviews/review-*.md | head -1
```

Ler o arquivo completo para extrair todos os problemas.

### 2. Identificar Problemas a Corrigir

Com base no argumento:

- **Número(s)** (ex: `3`, `1 2 5`): problemas com esses números
- **`critical`**: todos os CRITICAL
- **`high`**: todos os HIGH
- **`critical high`**: CRITICAL + HIGH
- **`todos`**: todos os problemas

Se nenhum argumento: perguntar ao usuário quais deseja corrigir.

### 3. Montar TODO List

`manage_todo_list` com um item por problema, incluindo número e descrição breve.

### 4. Aplicar Correções

Para cada problema:

1. Ler o arquivo mencionado (arquivo:linha do relatório)
2. Entender o problema e a solução sugerida
3. Aplicar a correção seguindo os padrões de `copilot-instructions.md`
4. Marcar como concluído no TODO

**Regras:**

- Não alterar código não relacionado ao problema
- Se a solução sugerida parece errada, informar e propor alternativa
- Não quebrar testes existentes

### 5. Confirmar

```
✅ X correções aplicadas.
   Próximo passo: /test para validar que nada quebrou, depois /rc.
```

### 6. Listar Lições para `/lesson`

No fim do `/fix-review`, sempre incluir uma seção de aprendizados para prevenir recorrência.

Formato:

```markdown
## 📚 Lições para /lesson

- **Problema corrigido:** #N [título curto]
  **Regra proposta:** [ação objetiva para evitar recorrência]
  **Destino sugerido:** [copilot-instructions.md | review.prompt.md | test.prompt.md | code.prompt.md]
```

Regras:

- 1 a 6 lições por execução
- Lições específicas e acionáveis
- Se não houver correção aplicada: `Nenhuma lição nova identificada nesta execução.`
