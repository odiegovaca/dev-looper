#!/usr/bin/env bash
# code-branch.sh [caminho-da-spec]
#
# Diz se a branch atual serve para implementar. Imprime BRANCH_OK (sim|nao),
# BRANCH_ATUAL e FEATURE_N em KEY=value. FEATURE_N sai do campo **Issue** da spec
# e vem vazio quando não há issue vinculada — a única decisão que sobra para o /code.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BRANCHES="$("$SCRIPT_DIR/release-branches.sh")" || exit 1
eval "$BRANCHES"

BRANCH_ATUAL="$(git branch --show-current)"

BRANCH_OK=sim
if [ -z "$BRANCH_ATUAL" ] || [ "$BRANCH_ATUAL" = "$PROD_BRANCH" ] || [ "$BRANCH_ATUAL" = "$INTEGRATION_BRANCH" ]; then
  BRANCH_OK=nao
fi

# Numa branch que já serve, o {N} sai do próprio nome dela; senão, da spec.
FEATURE_N=""
if [ "$BRANCH_OK" = sim ]; then
  FEATURE_N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"
else
  SPEC="${1:-}"
  [ -n "$SPEC" ] || SPEC="$(ls docs/issues/spec-*.md 2>/dev/null | head -1 || true)"
  # O `([^0-9]|$)` impede que a issue #3 case com a #30.
  [ -z "$SPEC" ] || FEATURE_N="$(grep -m1 -E '^\*\*Issue\*\*: \[?#[0-9]+([^0-9]|$)' "$SPEC" 2>/dev/null | sed -E 's/^\*\*Issue\*\*: \[?#([0-9]+).*/\1/' || true)"
fi

echo "BRANCH_OK=$BRANCH_OK"
echo "BRANCH_ATUAL=${BRANCH_ATUAL:-DETACHED}"
echo "FEATURE_N=$FEATURE_N"

if [ "$BRANCH_OK" = nao ]; then
  if [ -n "$FEATURE_N" ]; then
    echo "Branch '${BRANCH_ATUAL:-DETACHED}' não serve para implementar — crie feature/${FEATURE_N}-nome-descritivo antes de começar." >&2
  else
    echo "Branch '${BRANCH_ATUAL:-DETACHED}' não serve para implementar, e a spec não tem issue vinculada — rode /issue, ou pergunte o número ao usuário antes de criar a branch." >&2
  fi
fi
