#!/usr/bin/env bash
# review-prepare.sh [branch-de-integração]
#
# Resolve tudo que o /review precisa antes de analisar: arquivos alterados
# (sem lockfiles e reviews anteriores), {N} da feature, próximo {seq}, data e
# caminho do relatório. Falha com exit 1 se não houver o que revisar.
#
# Imprime N/SEQ/DATA/REPORT em KEY=value, seguido de "DIFF:" e o diff dos
# arquivos alterados contra o merge-base (cada um delimitado pelo próprio "diff --git").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sem argumento, usa a branch de integração do projeto.
INTEGRATION_BRANCH="${1:-}"
if [ -z "$INTEGRATION_BRANCH" ]; then
  BRANCHES="$("$SCRIPT_DIR/release-branches.sh")" || exit 1
  eval "$BRANCHES"
fi

if ! RAW_CHANGED_FILES="$("$SCRIPT_DIR/changed-files.sh" "$INTEGRATION_BRANCH")"; then
  echo "Falha ao obter arquivos alterados em relação a $INTEGRATION_BRANCH — rode 'git fetch origin $INTEGRATION_BRANCH' e, se a branch não existir no remoto, confira INTEGRATION_BRANCH em .github/scripts/release-branches.sh" >&2
  exit 1
fi

CHANGED_FILES="$(echo "$RAW_CHANGED_FILES" | grep -vE '^docs/reviews/|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|go\.sum|Gemfile\.lock|poetry\.lock' || true)"

if [ -z "$CHANGED_FILES" ]; then
  echo "Nenhuma mudança em relação a $INTEGRATION_BRANCH — nada para revisar. Commite a implementação (/code) antes de rodar o /review." >&2
  exit 1
fi

N="$("$SCRIPT_DIR/feature-number.sh")"
mkdir -p docs/reviews
# Daqui sai só o próximo {seq}; quem ordena os relatórios é o latest-review.sh.
LAST_REPORT="$("$SCRIPT_DIR/latest-review.sh" 2>/dev/null || true)"
LAST_SEQ="$(sed -E "s#.*review-${N}-([0-9]+)\.md#\1#" <<< "$LAST_REPORT")"
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
