---
description: Formalizar uma correção ou aprendizado em instrução permanente no projeto
agent: agent
tools: [read, edit, search]
argument-hint: "Descrição do aprendizado (ex: /lesson Controllers void não devem ter @ApiResponse tipado)"
---

# /lesson - Formalizar Aprendizado em Instrução

Transforme uma correção ou observação em regra permanente no projeto.

## Processo

### 1. Capturar o Aprendizado

Se o argumento foi fornecido, usá-lo diretamente.  
Se não foi fornecido, perguntar: _"Qual correção ou padrão você quer registrar?"_

### 2. Classificar o Destino

Listar todos os arquivos disponíveis em `.github/` (prompts, agents, copilot-instructions) e escolher o(s) mais adequado(s):

| Arquivo                                   | Quando usar                                                            |
| ----------------------------------------- | ---------------------------------------------------------------------- |
| `.github/copilot-instructions.md`         | Convenção geral do projeto (padrões, common pitfalls, auth, logging)   |
| `.github/prompts/review.prompt.md`        | Critério de revisão de código                                          |
| `.github/prompts/test.prompt.md`          | Padrão de testes                                                       |
| `.github/prompts/spec.prompt.md`          | Regra de especificação de issues ou critérios de aceite                |
| `.github/prompts/release.prompt.md`       | Regra do processo de release, versionamento ou changelog               |
| `.github/prompts/rc.prompt.md`            | Padrão de abertura ou estrutura de Pull Requests                       |
| `.github/prompts/fix-review.prompt.md`    | Padrão de correção de bugs                                             |
| `.github/prompts/issue.prompt.md`         | Padrão de criação ou triagem de issues                                 |
| `.github/prompts/code.prompt.md`          | Regra do fluxo de implementação                                        |
| `.github/prompts/status.prompt.md`        | Regra de acompanhamento de status ou progresso                         |
| `.github/prompts/setup.prompt.md`         | Regra de configuração de ambiente ou projeto                           |
| `.github/prompts/README.md`               | Documentação do fluxo geral — atualizar quando um prompt muda de comportamento, é adicionado ou removido |

> Se o aprendizado não se encaixar em nenhuma entrada da tabela, verificar se existe outro arquivo em `.github/` que seja mais adequado — a lista acima não é exaustiva.

Uma regra pode ir para mais de um arquivo se relevante em contextos distintos.

### 3. Verificar Duplicatas

Buscar no(s) arquivo(s) destino por termos-chave do aprendizado.  
Se já existir regra similar: informar onde está e perguntar se deseja **complementar** ou **substituir**.

### 4. Verificar Impacto em Outros Arquivos

Buscar em todo o `.github/` e no `README.md` do projeto por termos-chave que serão alterados ou removidos pela nova regra.  
Se encontrar referências inconsistentes: listar os arquivos afetados e incluí-los na proposta de alteração (passo 5).

### 5. Formatar a Regra

Seguir o estilo do arquivo destino:

- Em `copilot-instructions.md`: bullet conciso na seção mais adequada (ex: **Common Pitfalls**)
- Nos prompts: item de checklist ou exemplo de código

**Boas regras:** acionáveis, específicas, máximo 2-3 linhas.

### 6. Apresentar Proposta

```
## 📚 Proposta de Instrução

**Arquivo:** `.github/copilot-instructions.md`
**Seção:** Common Pitfalls
**Adicionar:**

- [texto da regra]

**Impacto em outros arquivos:** [lista ou "nenhum"]

**Confirmar? (responda "sim" para aplicar)**
```

### 7. Aplicar Após Confirmação

Somente após confirmação explícita: inserir a regra no arquivo na posição correta e propagar ajustes nos arquivos impactados.

Confirmar: _"Regra adicionada em [arquivo] > [seção]"_

---

> **Dica:** Use `/lesson` logo após corrigir algo manualmente — assim o próximo ciclo já começa com a regra incorporada.
