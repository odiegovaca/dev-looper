#!/usr/bin/env bash
# status-snapshot.sh
#
# Monta e imprime o snapshot completo do /status já no formato final
# markdown — o prompt só precisa mostrar a saída no chat, sem reinterpretar
# nada (mesmo padrão de review-finalize.sh para o /review).
#
# Sem argumentos: as branches vêm do release-branches.sh aqui mesmo. Recebê-las
# do prompt obrigava o /status a um eval só para devolver os valores, e era um
# par de estados atravessando o contexto do agente sem necessidade.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BRANCHES="$("$SCRIPT_DIR/release-branches.sh")" || exit 1
eval "$BRANCHES"

BRANCH="$(git branch --show-current)"

# Best-effort: atualiza a ref antes de comparar, mas não derruba o snapshot
# por causa de rede indisponível — só falha se a branch nem existir no
# remoto (typo no release-branches.sh, por exemplo).
git fetch origin "$PROD_BRANCH" --quiet 2>/dev/null || true
if ! git rev-parse --verify --quiet "origin/${PROD_BRANCH}" >/dev/null; then
  echo "Branch 'origin/${PROD_BRANCH}' não encontrada — confira PROD_BRANCH em .github/scripts/release-branches.sh (rode /setup se ainda não configurou) e se o fetch alcançou o remoto" >&2
  exit 1
fi

COMMITS_AHEAD_COUNT="$(git rev-list --count "origin/${PROD_BRANCH}..HEAD")"

PENDING_CHANGES="$(git status --short)"
if [ -z "$PENDING_CHANGES" ]; then
  PENDING_COUNT=0
else
  PENDING_COUNT="$(printf '%s\n' "$PENDING_CHANGES" | wc -l)"
fi

# Os dois sem 2>/dev/null: o stderr deles nomeia o motivo (arquivo de versão
# ilegível, relatório de cobertura ausente, /setup não configurado) e é o que
# distingue "ainda não rodei os testes" de "isto nunca foi configurado" — o
# segundo não se resolve com o /test que a cascata de NEXT_STEP vai sugerir.
VERSION="$("$SCRIPT_DIR/bump-version.sh" current || echo "desconhecida")"

COVERAGE="$("$SCRIPT_DIR/coverage.sh" || echo "não disponível")"
COVERAGE_DISPLAY="$COVERAGE"
[ "$COVERAGE" != "não disponível" ] && COVERAGE_DISPLAY="${COVERAGE}%"

# A meta é do projeto e mora no coverage.sh, onde o /test também a lê.
COVERAGE_TARGET="$("$SCRIPT_DIR/coverage.sh" --target 2>/dev/null || echo "?")"

# Numa feature branch, N resolve e escopa para a spec vinculada à issue da
# feature atual (mesmo campo **Issue** que create-issue.sh grava) — não
# faz sentido listar specs de outras features no status desta branch. Fora
# de uma feature branch (main/develop/HEAD destacado), não há "feature
# atual" — mostra o backlog inteiro pra ajudar a decidir o que puxar a
# seguir.
# O `[^0-9]|$` no fim do regex impede que a issue #7 case com a #70. Não achar
# nada aqui pode ser entrega (a spec foi
# para docs/issues/arquivo/) ou defeito de formato
N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"
if [ -n "$N" ]; then
  SPEC_FILES="$(grep -lE "^\*\*Issue\*\*: \[?#${N}([^0-9]|\$)" docs/issues/spec-*.md 2>/dev/null || true)"
  if [ -z "$SPEC_FILES" ]; then
    echo "Aviso: nenhuma spec ativa com '**Issue**: #${N}' em docs/issues/ — feature já entregue (spec arquivada) ou campo/formato alterado." >&2
  fi
else
  SPEC_FILES="$(ls docs/issues/spec-*.md 2>/dev/null || true)"
fi

# Status de cada spec já vem pronto pra exibir ("- `arquivo` → Status
# emoji") — mesmo regex de extração que create-issue.sh usa pro campo
# **Status**:, pra não duplicar interpretação de formato.
SPEC_LINES="- Nenhuma spec encontrada."
if [ -n "$SPEC_FILES" ]; then
  SPEC_LINES="$(while IFS= read -r f; do
    STATUS="$(grep -m1 '^\*\*Status\*\*:' "$f" | sed -E 's/^\*\*Status\*\*:[[:space:]]*`([^`]+)`.*/\1/' || true)"
    case "$STATUS" in
      Rascunho) EMOJI="📝" ;;
      "Em Revisão") EMOJI="👀" ;;
      Aprovada|Aprovado) EMOJI="✅" ;;
      "Issue criada") EMOJI="🔗" ;;
      *) EMOJI="❓" ;;
    esac
    echo "- \`$(basename "$f")\` → ${STATUS:-desconhecido} ${EMOJI}"
  done <<< "$SPEC_FILES")"
fi

LATEST_REVIEW="$("$SCRIPT_DIR/latest-review.sh" 2>/dev/null || echo "nenhum")"

# Veredito, data e estatísticas já foram computados uma vez por
# review-stats.sh dentro de review-finalize.sh e gravados no relatório
# ("**Data:**"/"**Estatísticas:**"/"**Veredito:**") — lê eles de volta em
# vez de reparsear os blocos "#### Problema" e recalcular do zero.
VEREDITO=""
STATUS_POS_FIX=""
REVIEW_SUMMARY="Nenhum review realizado ainda."
if [ "$LATEST_REVIEW" != "nenhum" ] && [ -f "$LATEST_REVIEW" ]; then
  # Os `|| true` daqui até REVIEW_STATS: sem eles um relatório sem uma dessas
  # linhas (formato antigo, arquivo editado à mão) derruba o /status inteiro na
  # atribuição, em vez de cair nos fallbacks logo abaixo.
  VEREDITO="$(grep -m1 '^\*\*Veredito:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Veredito:\*\*[[:space:]]*//' || true)"
  # O veredito é o retrato do código no momento do /review; se um /fix-review
  # rodou depois, quem vale é o status que ele gravou na seção "## Pós-fix".
  STATUS_POS_FIX="$(grep -m1 '^\*\*Status pós-fix:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Status pós-fix:\*\*[[:space:]]*//' || true)"
  REVIEW_DATA="$(grep -m1 '^\*\*Data:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Data:\*\*[[:space:]]*//' || true)"
  REVIEW_STATS="$(grep -m1 '^\*\*Estatísticas:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Estatísticas:\*\*[[:space:]]*//' || true)"
  REVIEW_SUMMARY="${REVIEW_DATA:-sem data} — ${REVIEW_STATS:-sem estatísticas}${STATUS_POS_FIX:+ (pós-fix: $STATUS_POS_FIX)}"
fi

IS_PROTECTED=false
if [ "$BRANCH" = "$PROD_BRANCH" ] || [ "$BRANCH" = "$INTEGRATION_BRANCH" ]; then
  IS_PROTECTED=true
fi

# Primeira regra que bater, nesta ordem.
if [ -z "$BRANCH" ]; then
  NEXT_STEP="git checkout — HEAD destacado, não dá pra determinar o workflow sem uma branch"
elif [ "$IS_PROTECTED" = true ] && [ "$PENDING_COUNT" -gt 0 ]; then
  NEXT_STEP="/code — mudanças pendentes fora de uma feature branch; cria a branch certa a partir da issue e preserva as mudanças"
elif [ "$IS_PROTECTED" = true ]; then
  NEXT_STEP="/code — branch protegida (${BRANCH}) sem trabalho em andamento"
elif [ -n "$N" ] && [ "$COMMITS_AHEAD_COUNT" -eq 0 ]; then
  NEXT_STEP="/code — branch de feature sem commits ainda; spec e issue já existem"
elif [ "$COVERAGE" = "não disponível" ]; then
  NEXT_STEP="/test — cobertura não disponível"
elif [ "$LATEST_REVIEW" = "nenhum" ]; then
  NEXT_STEP="/review — sem review para essa feature ainda"
elif [ "$STATUS_POS_FIX" = "bloqueado" ]; then
  NEXT_STEP="/fix-review — ainda restam problemas bloqueantes no último review"
elif [ "$STATUS_POS_FIX" = "revisar" ]; then
  NEXT_STEP="/review — bloqueante corrigido pelo /fix-review, aguardando revalidação"
elif [ "$STATUS_POS_FIX" = "liberado" ]; then
  NEXT_STEP="/rc — correções aplicadas e nenhum bloqueante pendente"
else
  case "$VEREDITO" in
    APROVADO) NEXT_STEP="/rc — review aprovado, sem problemas bloqueantes" ;;
    "APROVADO COM RESSALVAS") NEXT_STEP="/fix-review high — review com ressalvas, corrigir antes de /rc" ;;
    REPROVADO) NEXT_STEP="/fix-review critical — review reprovado, corrigir bloqueantes" ;;
    *) NEXT_STEP="/review — veredito do último review não reconhecido em $LATEST_REVIEW (formato mudou?)" ;;
  esac
fi

{
  echo "## Status do Workflow"
  echo
  echo "**Branch:** ${BRANCH:-DETACHED}"
  echo "**Versão:** $VERSION"
  echo "**Commits à frente:** $COMMITS_AHEAD_COUNT commit(s)"
  echo "**Mudanças pendentes:** $PENDING_COUNT arquivo(s)"
  echo
  echo "**Specs:**"
  echo
  echo "$SPEC_LINES"
  echo
  echo "**Cobertura:** $COVERAGE_DISPLAY (meta: ${COVERAGE_TARGET}%)"
  echo "**Último review:** $REVIEW_SUMMARY"
  echo
  echo "**Sugestão de próximo passo:** $NEXT_STEP"
}
