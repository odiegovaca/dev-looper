---
description: Configurar o workflow de IA para este projeto — detecta stack e gera copilot-instructions.md
agent: agent
tools: [read, edit, search, execute]
argument-hint: "Opcional: descrição do projeto se não houver README"
---

# /setup - Bootstrap do Workflow de IA

Configure o workflow de desenvolvimento com IA para este projeto. Detecta o stack automaticamente, faz perguntas pontuais e gera `.github/copilot-instructions.md` personalizado.

## Processo

### Step 0 — Verificar Pré-requisitos

```bash
command -v gh >/dev/null 2>&1 || {
  echo "❌ gh CLI não encontrado. Instale antes de continuar: https://cli.github.com"
  echo "   Consulte SETUP.md para instruções detalhadas."
  exit 1
}
```

Se o comando falhar, interromper imediatamente com a mensagem acima. Não prosseguir para os próximos passos.

### Step 1 — Detectar Stack

Ler em paralelo os arquivos de configuração que existirem:

```bash
# Detectar linguagem/runtime/framework
ls package.json pom.xml build.gradle go.mod requirements.txt Pipfile Gemfile composer.json 2>/dev/null
cat package.json 2>/dev/null | head -30
cat pom.xml 2>/dev/null | head -40
cat go.mod 2>/dev/null | head -20
```

```bash
# Detectar banco de dados (dependências e configuração)
grep -r "postgres\|mysql\|oracle\|sqlite\|mongodb\|redis\|db2\|sqlserver" \
  package.json pom.xml go.mod requirements.txt 2>/dev/null -i | head -20
```

```bash
# Detectar CI/CD
ls .github/workflows/ Jenkinsfile .gitlab-ci.yml 2>/dev/null
```

```bash
# Estrutura do projeto
find src -type d -maxdepth 3 2>/dev/null | head -30
find . -name "*.env.example" -o -name ".env.example" 2>/dev/null | head -5
```

Ler também:
- `README.md` (se existir) — contexto de negócio
- `CHANGELOG.md` (se existir) — histórico de mudanças, versão atual
- Um arquivo de código representativo (ex: controller ou service principal)

### Step 2 — Perguntas Pontuais

Com base no que foi detectado, fazer **apenas as perguntas que não puderam ser inferidas**. Máximo 5 perguntas, uma de cada vez se necessário. Exemplos:

- "Detectei PostgreSQL via JPA. Existe algum padrão de Repository que o time usa? (ex: projections, QueryDSL, JPQL nativo)"
- "Qual é o padrão de tratamento de erros? (ex: exceções customizadas, error codes, middleware global)"
- "Qual a meta de cobertura de testes do time? (padrão: 80%)"
- "A branch de integração é `develop` ou outra?"
- "Usa versionamento semver com sufixo RC? (ex: `1.2.0-rc.1`)"

### Step 3 — Gerar copilot-instructions.md

Usar `copilot-instructions.template.md` (se disponível em `.github/`) como base. Substituir **todos os `[DEFINIR: ...]`** com informações reais detectadas ou informadas.

Gerar `.github/copilot-instructions.md` com:

1. **Project Overview**: Nome, propósito, stack
2. **Architecture**: Stack completo, estrutura de pastas real
3. **Key Conventions**: Padrões reais detectados no código — não inventar
4. **Development Commands**: Comandos exatos do `package.json`/`Makefile`/`pom.xml`
5. **Integration Points**: APIs e sistemas externos detectados
6. **Common Pitfalls**: Armadilhas óbvias do stack escolhido (ex: lazy loading JPA, serialização circular Node.js)
7. **Testing Conventions**: Padrão de teste do projeto com exemplo real
8. **Coverage Report**: Comando para ler a cobertura atual sem rodar os testes novamente. Exemplos por stack:
   - **Node.js/Jest**: `cat coverage/coverage-summary.json | node -e "const d=require('fs').readFileSync('/dev/stdin','utf8'),j=JSON.parse(d);console.log(j.total.statements.pct+'%')"`
   - **Java/JaCoCo**: `awk -F',' 'NR>1{c+=$4;t+=$3+$4}END{printf "%.1f%%\n",c/t*100}' target/site/jacoco/jacoco.csv`
   - **Python/pytest-cov**: `coverage report --format=total 2>/dev/null`
   - **Go**: `go tool cover -func=coverage.out 2>/dev/null | grep total | awk '{print $3}'`
   - Se não aplicável: deixar `[DEFINIR: comando para ler cobertura do relatório gerado]`
9. **Release Workflow**: Estratégia de branches detectada ou informada

> ⚠️ **Regra**: Se não souber, deixe `[DEFINIR: ...]` — não invente. Melhor incompleto e correto do que completo e errado.

Após gerar o arquivo, remover o template (não é mais necessário):

```bash
rm -f .github/copilot-instructions.template.md
```

### Step 4 — Adaptar code.prompt.md

Ler `.github/prompts/code.prompt.md`.

Substituir a seção **"Ordem de Implementação"** com fases específicas do stack detectado, seguindo o critério:

1. **Persistência** — modelos, entidades, migrations, repositórios (se houver banco)
2. **Lógica de negócio** — serviços, validações, DTOs, mapeamentos
3. **Exposição** — controllers, handlers, rotas, endpoints
4. **Configuração** — registro de dependências, variáveis de ambiente, wiring do framework

Usar os artefatos reais do stack (ex: `@Entity` + `JpaRepository` para Spring, `sqlc` + `pgx` para Go, `Schema` + `Router` para FastAPI) e os padrões detectados no código do projeto. Se o projeto for frontend, adaptar as fases para tipos → data fetching → componente → testes.

### Step 5 — Confirmar Resultado

Mostrar resumo do que foi configurado:

```
## ✅ Workflow configurado para [NOME DO PROJETO]

**Stack detectado:**
- Runtime: [...]
- Framework: [...]
- Banco: [...]

**Arquivos gerados/atualizados:**
- `.github/copilot-instructions.md` → [N] seções preenchidas, [M] com [DEFINIR] pendente
- `.github/prompts/code.prompt.md` → Fases adaptadas para [STACK]

**Pendências (preencher manualmente):**
- [ ] [Lista de [DEFINIR] que ficaram em aberto]

**Próximo passo:** `/spec <descrição da feature>` para começar o desenvolvimento
```

---

> **Nota:** O `/setup` é idempotente — pode rodar novamente quando o projeto evoluir para atualizar o `copilot-instructions.md`.
