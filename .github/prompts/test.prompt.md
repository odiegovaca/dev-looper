---
description: Executar, corrigir e melhorar testes até meta de cobertura
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Meta de cobertura em % (padrão: 80)"
---

# /test - Completar Cobertura de Testes

Completar cobertura de testes até meta de **statements** (padrão: 80%, ou o valor passado em `$ARGUMENTS`), priorizando pelo maior ganho real no `%` global — não pelo pior percentual isolado (ver Passo 3).

**Arquivos Protegidos** (ver `copilot-instructions.md`): não editar `.github/prompts/*.md` nem `copilot-instructions.md`.

## Processo

### 1 — Executar

```bash
.github/scripts/validate.sh test
```

### 2 — Corrigir

Falhas identificadas (máx 3 iterações). Se persistir após o limite, parar e reportar ao usuário — não prosseguir.

### 3 — Priorizar

Cruzar arquivos da branch (`.github/scripts/changed-files.sh $INTEGRATION_BRANCH` — mesmo script usado pelo `/review`; `$INTEGRATION_BRANCH` lido de `copilot-instructions.md`) com a saída de `.github/scripts/coverage.sh --priority` (linhas `arquivo,rank_sum`, já ordenadas por prioridade — menor `rank_sum` primeiro). Essa ordem combina `pct` baixo **e** alto volume de statements não cobertos — não o pior `%` isolado, que favorece arquivo pequeno e trivial sobre arquivo grande com gap real. É cálculo do script, não estimativa manual.

Montar `manage_todo_list` com o resultado antes de completar (Passo 4).

### 4 — Completar

Escrever testes em até 3 ciclos de **escrever → `.github/scripts/validate.sh test` → `coverage.sh` → `coverage.sh --priority`**. O `validate.sh test` de cada ciclo regera o relatório e confirma que os testes novos passam; o `coverage.sh` (total) logo em seguida diz se a meta já foi atingida — se sim, parar o loop e ir para o Passo 5; se não, `coverage.sh --priority` recalcula o próximo gap a cobrir. Se um teste novo falhar, corrigir antes de seguir para o próximo gap.

Se a meta não for atingida após os 3 ciclos, parar mesmo assim e seguir para o Passo 5 — o `%` do último ciclo é o que vai para o relatório final, marcado como meta não atingida.

- **Fase 1**: gaps nos arquivos da branch, na ordem do `coverage.sh --priority` — casos de borda, branches não cobertas. Só avançar para a Fase 2 depois de esgotar os gaps aqui
- **Fase 2**: se a meta ainda não foi atingida, até 10 arquivos do restante do projeto, na mesma ordem (recalculada sobre o restante)
- Ignorar código gerado, migrations e arquivos de configuração — não contam para a meta

### 5 — Validar

```bash
.github/scripts/validate.sh lint build
```

### 6 — Confirmar

```markdown
## Cobertura de Testes

**Statements:** XX% → YY% (+ganho%)
**Meta:** ZZ% — [ATINGIDA | NÃO ATINGIDA]
**Arquivos testados:** N (Fase 1: n1, Fase 2: n2)
```

## Regras

- Não reescrever testes existentes que já passam — apenas complementar
- Priorizar trabalho recente (arquivos da branch) antes de expandir para o restante — ver Passo 3 para a ordem dentro de cada grupo
- Meta padrão: **80%** de statements — é o critério de parada, não o critério de escolha de onde testar
- Nunca alterar código de produção para facilitar testes — adaptar os testes
- Consultar `copilot-instructions.md` (seção Testing Conventions) para estrutura padrão dos testes, mocks e localização dos arquivos

## Próximos Passos

- ✅ **Meta atingida**: `git commit "test: completa cobertura"` como checkpoint, depois `/review` para revisão de qualidade antes do PR
- ⚠️ **Meta não atingida**: Informar lacunas e arquivos prioritários para cobertura manual
