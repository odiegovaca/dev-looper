#!/usr/bin/env bash
# status-snapshot.sh <prod-branch> <integration-branch>
#
# Monta e imprime o snapshot completo do /status já no formato final
# markdown — o prompt só precisa mostrar a saída no chat, sem reinterpretar
# nada (mesmo padrão de review-finalize.sh para o /review).
#
# PROD_BRANCH/INTEGRATION_BRANCH entram como argumentos — mesmos valores que
# code.prompt.md/rc.prompt.md/release.prompt.md já lêem de
# release-branches.sh, centralizado lá a partir de copilot-instructions.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROD_BRANCH="${1:-}"
INTEGRATION_BRANCH="${2:-}"
if [ -z "$PROD_BRANCH" ] || [ -z "$INTEGRATION_BRANCH" ]; then
  echo "Uso: status-snapshot.sh <prod-branch> <integration-branch>" >&2
  exit 1
fi

BRANCH="$(git branch --show-current)"

# Best-effort: atualiza a ref antes de comparar, mas não derruba o snapshot
# por causa de rede indisponível — só falha se a branch nem existir no
# remoto (typo em copilot-instructions.md, por exemplo).
git fetch origin "$PROD_BRANCH" --quiet 2>/dev/null || true
if ! git rev-parse --verify --quiet "origin/${PROD_BRANCH}" >/dev/null; then
  echo "Branch 'origin/${PROD_BRANCH}' não encontrada — nome correto em copilot-instructions.md? fetch funcionou?" >&2
  exit 1
fi

COMMITS_AHEAD_COUNT="$(git rev-list --count "origin/${PROD_BRANCH}..HEAD")"

PENDING_CHANGES="$(git status --short)"
if [ -z "$PENDING_CHANGES" ]; then
  PENDING_COUNT=0
else
  PENDING_COUNT="$(printf '%s\n' "$PENDING_CHANGES" | wc -l)"
fi

VERSION="$("$SCRIPT_DIR/bump-version.sh" current 2>/dev/null || echo "desconhecida")"

COVERAGE="$("$SCRIPT_DIR/coverage.sh" 2>/dev/null || echo "não disponível")"
COVERAGE_DISPLAY="$COVERAGE"
[ "$COVERAGE" != "não disponível" ] && COVERAGE_DISPLAY="${COVERAGE}%"

# Numa feature branch, N resolve e escopa para a spec vinculada à issue da
# feature atual (mesmo campo **Issue**: #N que create-issue.sh grava) — não
# faz sentido listar specs de outras features no status desta branch. Fora
# de uma feature branch (main/develop/HEAD destacado), não há "feature
# atual" — mostra o backlog inteiro pra ajudar a decidir o que puxar a
# seguir.
N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"
if [ -n "$N" ]; then
  SPEC_FILES="$(grep -lE "^\*\*Issue\*\*: #${N}\$" docs/issues/spec-*.md 2>/dev/null || true)"
else
  SPEC_FILES="$(ls docs/issues/spec-*.md 2>/dev/null || true)"
fi

# Status de cada spec já vem pronto pra exibir ("- `arquivo` → Status
# emoji") — mesmo regex de extração que create-issue.sh usa pro campo
# **Status**:, pra não duplicar interpretação de formato.
SPEC_LINES="- Nenhuma spec encontrada."
if [ -n "$SPEC_FILES" ]; then
  SPEC_LINES="$(while IFS= read -r f; do
    STATUS="$(grep -m1 '^\*\*Status\*\*:' "$f" | sed -E 's/^\*\*Status\*\*:[[:space:]]*`([^`]+)`.*/\1/')"
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
REVIEW_SUMMARY="Nenhum review realizado ainda."
if [ "$LATEST_REVIEW" != "nenhum" ] && [ -f "$LATEST_REVIEW" ]; then
  VEREDITO="$(grep -m1 '^\*\*Veredito:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Veredito:\*\*[[:space:]]*//')"
  REVIEW_DATA="$(grep -m1 '^\*\*Data:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Data:\*\*[[:space:]]*//')"
  REVIEW_STATS="$(grep -m1 '^\*\*Estatísticas:\*\*' "$LATEST_REVIEW" | sed -E 's/^\*\*Estatísticas:\*\*[[:space:]]*//')"
  REVIEW_SUMMARY="${REVIEW_DATA} — ${REVIEW_STATS}"
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
  echo "**Cobertura:** $COVERAGE_DISPLAY (meta: 80%)"
  echo "**Último review:** $REVIEW_SUMMARY"
  echo
  echo "**Sugestão de próximo passo:** $NEXT_STEP"
}
