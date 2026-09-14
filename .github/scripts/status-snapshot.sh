#!/usr/bin/env bash
# status-snapshot.sh
#
# Imprime o snapshot do /status já em markdown final — usar a saída sem alterações.
# Sem argumentos: as branches saem do release-branches.sh aqui mesmo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BRANCHES="$("$SCRIPT_DIR/release-branches.sh")" || exit 1
eval "$BRANCHES"

BRANCH="$(git branch --show-current)"

# Atualiza a ref antes de comparar, sem derrubar o snapshot se a rede faltar —
# só falha se a branch nem existir no remoto.
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

# Os dois sem 2>/dev/null: o stderr deles distingue "ainda não rodei os testes"
# de "isto nunca foi configurado", que o /test sugerido abaixo não resolve.
VERSION="$("$SCRIPT_DIR/bump-version.sh" current || echo "desconhecida")"

COVERAGE="$("$SCRIPT_DIR/coverage.sh" || echo "não disponível")"
COVERAGE_DISPLAY="$COVERAGE"
[ "$COVERAGE" != "não disponível" ] && COVERAGE_DISPLAY="${COVERAGE}%"

COVERAGE_TARGET="$("$SCRIPT_DIR/coverage.sh" --target 2>/dev/null || echo "?")"

# Numa feature branch, mostra só a spec da issue atual; fora dela, o backlog inteiro,
# que ajuda a decidir o que puxar. O `[^0-9]|$` impede que a issue #7 case com a #70.
N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"
if [ -n "$N" ]; then
  SPEC_FILES="$(grep -lE "^\*\*Issue\*\*: \[?#${N}([^0-9]|\$)" docs/issues/spec-*.md 2>/dev/null || true)"
  if [ -z "$SPEC_FILES" ]; then
    echo "Aviso: nenhuma spec ativa com '**Issue**: #${N}' em docs/issues/ — feature já entregue (spec arquivada) ou campo/formato alterado." >&2
  fi
else
  SPEC_FILES="$(ls docs/issues/spec-*.md 2>/dev/null || true)"
fi

# Cada spec sai pronta para exibir: "- `arquivo` → Status emoji".
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

# Lê o que o review-finalize.sh já gravou no relatório, em vez de reparsear os blocos.
VEREDITO=""
STATUS_POS_FIX=""
BLOQUEANTES=""
REVIEW_SUMMARY="Nenhum review realizado ainda."
if [ "$LATEST_REVIEW" != "nenhum" ] && [ -f "$LATEST_REVIEW" ]; then
  # `|| true` para relatório em formato antigo cair nos fallbacks abaixo.
  VEREDITO="$(grep -m1 '^\*\*Veredito:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Veredito:\*\*[[:space:]]*//' || true)"
  STATUS_POS_FIX="$(grep -m1 '^\*\*Status pós-fix:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Status pós-fix:\*\*[[:space:]]*//' || true)"
  # Escrita pelo fix-review-finalize.sh; sem ela o next-step.sh sugeriria "/fix-review"
  # sem seletor. "nenhum" é o vazio no relatório, e volta a ser vazio aqui.
  BLOQUEANTES="$(grep -m1 '^\*\*Bloqueantes pendentes:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Bloqueantes pendentes:\*\*[[:space:]]*//' || true)"
  [ "$BLOQUEANTES" != "nenhum" ] || BLOQUEANTES=""
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
else
  NEXT_STEP="$("$SCRIPT_DIR/next-step.sh" "$VEREDITO" "$STATUS_POS_FIX" "$BLOQUEANTES")"
fi

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
