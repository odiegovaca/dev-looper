---
description: Formalizar uma correção ou aprendizado em instrução permanente no projeto
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Descrição do aprendizado (ex: /lesson Controllers void não devem ter @ApiResponse tipado)"
---

# /lesson - Formalizar Aprendizado em Instrução

## Processo

### 1 — Capturar o Aprendizado

Sem argumento, perguntar: _"Qual correção ou padrão você quer registrar?"_

Pode vir mais de uma; tratar cada lição separadamente daqui em diante.

### 2 — Decidir se Vira Instrução

Instrução escrita é o último recurso. Nesta ordem:

- **Dá para tornar o erro impossível?**
- **Dá para o erro se denunciar sozinho?**
- **É regra permanente, ou fato de agora?** O que descreve o estado presente é tarefa.

Nada interrompe: a lição que sai aqui é anotada com o que a substitui — qual mudança e onde — e reaparece no passo 5.

### 3 — Classificar o Destino

```bash
.github/scripts/list-lesson-targets.sh
```

Escolher pela `description` de cada um; se nenhuma decidir, abrir o candidato e conferir. Uma regra pode ir para mais de um arquivo.

### 4 — Buscar Termos-Chave e Analisar Impacto

Buscar termos-chave da lição em todo o `.github/` e no `README.md`.

- **No destino**: já existe regra similar — anotar onde, e se é para complementar ou substituir
- **Fora do destino**: referência que ficará inconsistente — incluir os arquivos na proposta

### 5 — Apresentar Proposta

Formatar cada regra no estilo do arquivo destino, integrando na seção existente mais relacionada. **Boas regras:** acionáveis, específicas, máximo 2-3 linhas.

Uma proposta só para todas as lições: um bloco por destino, o resto uma vez no fim.

```markdown
## 📚 Proposta de Instrução

**Arquivo:** [caminho]
**Seção:** [seção]
**Adicionar:**
- [texto da regra]
**Regra similar existente:** [onde está, complementar ou substituir — ou "nenhuma"]

**Impacto em outros arquivos:** [lista ou "nenhum"]
**Fora do arquivo de instrução:** [uma linha por lição que saiu no passo 2 — ou "nenhuma"]

**Confirmar? (responda "sim" para aplicar)**
```

### 6 — Aplicar Após Confirmação

Somente após confirmação explícita: inserir cada regra na posição correta e propagar os ajustes.

```markdown
✅ Regra adicionada em [arquivo] > [seção].
```
