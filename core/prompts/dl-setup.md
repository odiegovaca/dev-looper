---
description: Configurar o workflow de IA para este projeto — detecta stack e gera AGENTS.md
tools: [read, edit, search, execute]
argument-hint: "Descrição do projeto (opcional, usada se não houver README)"
---

# /dl-setup - Bootstrap do Workflow de IA

## Processo

### 1 — Verificar Pré-requisitos

```bash
chmod +x {{SCRIPTS_DIR}}/*.sh
{{SCRIPTS_DIR}}/check-prereqs.sh
```

Se falhar, repassar a mensagem e parar.

### 2 — Detectar Stack

Explorar o repositório e identificar: linguagem/runtime, framework, banco de dados (driver/ORM), CI/CD, comandos de instalação/teste/lint/build, comando que grava a versão (quando o ecossistema tiver um), estrutura real do código-fonte, variáveis de ambiente esperadas, contexto de negócio (via `README.md`, se existir), histórico de mudanças e versão atual (via `CHANGELOG.md`, se existir) e padrões reais de código (a partir de um arquivo representativo, ex: controller ou service principal). Usar julgamento sobre quais arquivos abrir e como buscar em cada caso.

### 3 — Perguntas Pontuais

Com base no que foi detectado, fazer **apenas as perguntas pontuais e fechadas que não puderam ser inferidas**. Máximo 5, feitas juntas numa única mensagem — não uma a uma — exceto quando uma pergunta depende da resposta de outra. O usuário pode responder só as que quiser.

### 4 — Gerar AGENTS.md

Base: o `AGENTS.template.md`, se existir; senão, o `AGENTS.md` atual, alterando só as seções afetadas pela mudança de stack e preservando o resto.

Substituir cada `[DEFINIR: ...]` pelo valor real detectado ou informado. O texto dentro do marcador é o contrato do valor — formato, unidade e o que não incluir.

> ⚠️ **Regra**: Se não souber, deixe `[DEFINIR: ...]` — não invente.

Após gerar o arquivo, remover o template:

```bash
rm -f AGENTS.template.md
```

### 5 — Configurar Scripts Determinísticos

Preencher os `[DEFINIR]` de `bump-version.sh`, `coverage.sh`, `validate.sh` e `release-branches.sh` com os dados do Passo 2 — cada marcador declara o que espera.

```bash
chmod +x {{SCRIPTS_DIR}}/*.sh
bash -n {{SCRIPTS_DIR}}/{bump-version,coverage,validate,release-branches}.sh
```

Corrigir qualquer erro de sintaxe antes de seguir.

### 6 — Adaptar dl-code{{PROMPT_EXT}}

Ler `{{PROMPTS_DIR}}/dl-code{{PROMPT_EXT}}` e substituir as subseções `2.N` da seção "Implementação" pelos artefatos reais do stack detectado e pelos padrões observados no código, mantendo a progressão persistência → lógica de negócio → exposição → configuração. Num projeto frontend, a progressão vira tipos → data fetching → componente → testes.

### 7 — Confirmar

```bash
{{SCRIPTS_DIR}}/setup-check.sh
```

```markdown
## ✅ Workflow configurado para [NOME DO PROJETO]

**Stack detectado:**
- Runtime: [...]
- Framework: [...]
- Banco: [...]

**Arquivos gerados/atualizados:**
- `AGENTS.md`
- `{{PROMPTS_DIR}}/dl-code{{PROMPT_EXT}}` → fases adaptadas para [STACK]
- `{{SCRIPTS_DIR}}/*.sh` → [lista dos scripts preenchidos no Passo 5]

**Pendências:** [a saída do setup-check.sh]

**Próximo passo:** `/dl-spec <descrição da feature>` para começar o desenvolvimento
```
