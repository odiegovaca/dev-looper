#!/usr/bin/env bash
# review-prepare.sh <integration-branch>
#
# Resolve tudo que o /review precisa antes de analisar: arquivos alterados
# (filtrados de lockfiles e relatórios de review anteriores), identificador
# de feature, próximo {seq}, data e caminho do relatório. Falha com exit 1
# e mensagem no stderr se não houver mudanças em relação à branch de
# integração — nada para revisar, evita gastar análise à toa.
#
# Imprime N/SEQ/DATA/REPORT (uma variável por linha), seguido de "DIFF:" e o
# diff unificado de todos os arquivos alterados contra o merge-base, numa
# chamada só — cada arquivo vem delimitado pelo próprio cabeçalho
# "diff --git a/arquivo b/arquivo", dispensando uma lista de arquivos à parte.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INTEGRATION_BRANCH="${1:-}"
[ -n "$INTEGRATION_BRANCH" ] || { echo "Uso: review-prepare.sh <integration-branch>" >&2; exit 1; }

if ! RAW_CHANGED_FILES="$("$SCRIPT_DIR/changed-files.sh" "$INTEGRATION_BRANCH")"; then
  echo "Falha ao obter arquivos alterados em relação a $INTEGRATION_BRANCH — branch existe no remoto? fetch funcionou?" >&2
  exit 1
fi

CHANGED_FILES="$(echo "$RAW_CHANGED_FILES" | grep -vE '^docs/reviews/|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|go\.sum|Gemfile\.lock|poetry\.lock' || true)"

if [ -z "$CHANGED_FILES" ]; then
  echo "Nenhuma mudança em relação a $INTEGRATION_BRANCH — nada para revisar." >&2
  exit 1
fi

N="$("$SCRIPT_DIR/feature-number.sh")"
mkdir -p docs/reviews
LAST_SEQ=$(ls "docs/reviews/review-${N}-"*.md 2>/dev/null | sed -E "s#.*review-${N}-([0-9]+)\.md#\1#" | sort -n | tail -1 || true)
SEQ=$(( ${LAST_SEQ:-0} + 1 ))
DATA=$(date +%Y-%m-%d-%H%M%S)
REPORT="docs/reviews/review-${N}-${SEQ}.md"

mapfile -t FILES <<< "$CHANGED_FILES"
DIFF="$(git diff "origin/$INTEGRATION_BRANCH...HEAD" -- "${FILES[@]}")"

echo "N=$N"
echo "SEQ=$SEQ"
echo "DATA=$DATA"
echo "REPORT=$REPORT"
echo "DIFF:"
echo "$DIFF"
