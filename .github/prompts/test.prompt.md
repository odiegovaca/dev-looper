---
description: Executar, corrigir e melhorar testes até meta de cobertura
agent: agent
tools: [read, edit, search, execute, todo]
argument-hint: "Meta de cobertura em % (padrão: 80)"
---

# /test

Completar cobertura de testes até meta de **statements** (padrão: 80%). Os testes básicos (happy path + erros esperados) já foram criados pelo `/code` — este comando foca nos gaps: casos de borda, branches não cobertas e arquivos sem teste.

## Workflow

1. **Executar**: Usar comando de testes de `copilot-instructions.md` (seção Development Commands)
2. **Corrigir**: Identificar falhas, analisar causa, aplicar correções (máx 3 iterações)
3. **Analisar**: Extrair cobertura de statements com `.github/scripts/coverage.sh`
4. **Priorizar**: Arquivos modificados na branch primeiro (`git diff`, peso 100x), depois restante (peso 1x)
5. **Completar**: Fase 1 — gaps nos arquivos da branch (casos de borda, edge cases); Fase 2 — até 10 do restante (se necessário)
6. **Reportar**: Cobertura inicial → final (+ganho%), status da meta, arquivos testados

## Regras

- Não reescrever testes existentes que já passam — apenas complementar
- Priorizar trabalho recente (arquivos da branch) antes de expandir para o restante
- Executar workflow completo e sequencial até atingir meta ou limites de iteração
- Meta padrão: **80%** de statements
- Nunca alterar código de produção para facilitar testes — adaptar os testes

## Convenções de Teste

Consultar `copilot-instructions.md` (seção Testing Conventions) para:

- Estrutura padrão dos testes (describe/it, Given-When-Then, etc.)
- Como mockar dependências no framework do projeto
- Localização dos arquivos de teste

## Próximos Passos

- ✅ **Meta atingida**: Execute `/review` para revisão de qualidade antes do PR
- ⚠️ **Meta não atingida**: Informar lacunas e arquivos prioritários para cobertura manual
