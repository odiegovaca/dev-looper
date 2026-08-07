---
description: Formalizar uma correção ou aprendizado em instrução permanente no projeto
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Descrição do aprendizado (ex: /lesson Controllers void não devem ter @ApiResponse tipado)"
---

# /lesson - Formalizar Aprendizado em Instrução

Transforme uma correção ou observação em regra permanente no projeto.

## Processo

### 1 — Capturar o Aprendizado

Se o argumento foi fornecido, usá-lo diretamente.  
Se não foi fornecido, perguntar: _"Qual correção ou padrão você quer registrar?"_

### 2 — Classificar o Destino

```bash
.github/scripts/list-lesson-targets.sh
```

Escolher o(s) destino(s) mais adequado(s) com base na `description` de cada um; se nenhuma deixar claro, abrir o arquivo candidato e conferir o conteúdo antes de decidir.

Uma regra pode ir para mais de um arquivo se relevante em contextos distintos.

### 3 — Buscar Termos-Chave e Analisar Impacto

Buscar em todo o `.github/` e no `README.md` do projeto por termos-chave do aprendizado.

- **Match no(s) arquivo(s) destino**: já existe regra similar — informar onde está e perguntar se deseja **complementar** ou **substituir**
- **Match em outros arquivos**: referência que ficará inconsistente com a nova regra — listar os arquivos afetados e incluí-los na proposta de alteração (próximo passo)

### 4 — Apresentar Proposta

Formatar a regra seguindo o estilo do arquivo destino, integrando na seção ou passo existente mais relacionado — evitar criar algo novo solto quando um já cobre o tema. **Boas regras:** acionáveis, específicas, máximo 2-3 linhas.

```markdown
## 📚 Proposta de Instrução

**Arquivo:** `.github/copilot-instructions.md`
**Seção:** Common Pitfalls
**Adicionar:**

- [texto da regra]

**Impacto em outros arquivos:** [lista ou "nenhum"]

**Confirmar? (responda "sim" para aplicar)**
```

### 5 — Aplicar Após Confirmação

Somente após confirmação explícita: inserir a regra no arquivo na posição correta e propagar ajustes nos arquivos impactados.

```markdown
✅ Regra adicionada em [arquivo] > [seção].
```
