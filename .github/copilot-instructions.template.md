# Copilot Instructions: [NOME DO PROJETO]

<!-- Onboarding do agente, lido no início de cada sessão. Rode /setup para preencher. -->

## Project Overview

[DEFINIR: 2-3 frases — o que o projeto faz, para quem, e a linguagem principal. Sem histórico e sem roadmap.]

---

## Architecture

### Core Stack

- **Language/Runtime**: [DEFINIR: nome e versão maior]
- **Framework**: [DEFINIR: nome e versão maior; "nenhum" se for biblioteca pura]
- **Database**: [DEFINIR: banco e a camada de acesso usada; "nenhum" se não houver]
- **Auth**: [DEFINIR: mecanismo e onde é aplicado; "nenhum" se não houver]
- **Observability**: [DEFINIR: o que emite log, métrica e trace; "nenhum" se não houver]
- **Testing**: [DEFINIR: framework de teste e biblioteca de mock]

### Module/Package Structure

```
[DEFINIR: as pastas reais do código-fonte, uma por linha, cada uma com o que guarda.
Só o que existe no repositório — sem pasta planejada e sem node_modules/build/vendor.]
```

---

## Key Conventions

### Exception Handling

[DEFINIR: como este projeto sinaliza e trata erro, com um trecho real do código — tipo/estrutura usada, onde é capturado e qual o formato da resposta de erro.]

### Authentication Pattern

[DEFINIR: onde a credencial é validada, em que header/campo ela chega, e o que o payload carrega. "Não se aplica" se não houver auth.]

### Logging

[DEFINIR: qual logger, como se obtém a instância, e o que nunca pode ser logado neste domínio. Um trecho real do código.]

### Environment Variables

[DEFINIR: uma linha por variável obrigatória — nome, para que serve e como o código a lê. Sem valores reais de segredo.]

### Database / Repository Pattern

[DEFINIR: como uma consulta e uma escrita são feitas aqui, com um trecho real. "Não se aplica" se não houver banco.]

---

## Padrões Obrigatórios

Checklist derivado das seções acima — vale para toda implementação ou correção de código, não só a fase em que o padrão foi introduzido. Verificar antes de considerar qualquer fase/correção concluída:

- **Exception handling**: usar tipos do projeto, não exceções genéricas
- **Logging**: usar o logger do projeto, nunca escrita direta em stdout/stderr em produção
- **Variáveis de ambiente**: sempre via função/método helper do projeto, nunca lendo o ambiente direto
- **Segurança**: nunca logar tokens, senhas ou dados pessoais
- [DEFINIR: os padrões deste stack que um agente violaria sem perceber — acrescente aqui, ou remova esta linha]

---

## Arquivos Protegidos

`.github/prompts/*.md` e este arquivo (`copilot-instructions.md`) só podem ser alterados por `/setup` e `/lesson`. Nenhum outro comando deve editá-los, mesmo incidentalmente — mudanças aqui alteram o comportamento de todo o workflow, e precisam passar pela revisão deliberada que esses dois comandos representam.

Falha três vezes seguidas no mesmo erro, em qualquer comando, é sinal de parar e reportar ao usuário — não de tentar uma quarta vez.

---

## Development Commands

```bash
# Instalar dependências
[DEFINIR: comando exato, como roda na raiz do repositório]

# Executar em desenvolvimento
[DEFINIR: comando exato]

# Executar testes
[DEFINIR: comando exato]

# Cobertura de testes
[DEFINIR: comando exato que GERA o relatório de cobertura em disco]

# Lint / formatação
[DEFINIR: comando exato]

# Build
[DEFINIR: comando exato]
```

**Caminho do relatório de cobertura:** ver `COVERAGE_REPORT` em `.github/scripts/coverage.sh`

---

## Integration Points

[DEFINIR: uma subseção por sistema externo que este projeto chama ou que o chama — endereço base, como autentica, quais operações usa e onde mora o cliente no código. "Nenhuma" se o projeto não integra com nada.]

---

## Common Pitfalls

<!-- Adicione aqui erros recorrentes via /lesson -->

- [DEFINIR: armadilhas deste stack e deste código que já causaram erro, uma por linha. Só o que foi observado aqui — não a lista genérica da linguagem.]

---

## Testing Conventions

[DEFINIR: a estrutura padrão de um teste unitário deste projeto, com um trecho real — onde os arquivos ficam, como se nomeiam, e como as dependências são mockadas.]

**Meta de cobertura:** ver `COVERAGE_TARGET` em `.github/scripts/coverage.sh` — é de lá que `/test` e `/status` a leem

---

## Release Workflow

- **Branches**: ver `.github/scripts/release-branches.sh`
- **Features**: `feature/{N}-nome-descritivo` a partir da branch de integração — `{N}` é o número da issue, e é por ele que `/review` e `/fix-review` acham o relatório da feature
- **Versionamento**: [DEFINIR: esquema de versão e onde o sufixo de pré-lançamento é usado]
- **Arquivos de versão**: ver `VERSION_FILES` em `.github/scripts/bump-version.sh`
- **CHANGELOG no desenvolvimento**: uma única seção por ciclo, sempre consolidada — cada RC reescreve a do topo com o delta acumulado, header na versão RC atual e `Unreleased` no lugar da data; o `/release` troca esse header pela versão final
