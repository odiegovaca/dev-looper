#!/usr/bin/env bash
# release-branches.sh
#
# Imprime PROD_BRANCH e INTEGRATION_BRANCH, uma por linha em KEY=value —
# usar com `eval "$(release-branches.sh)"`.
set -euo pipefail

# Preenchidos por /setup com as branches detectadas no projeto.
PROD_BRANCH="[DEFINIR: nome da branch de producao]"
INTEGRATION_BRANCH="[DEFINIR: nome da branch de integracao]"

if [[ "$PROD_BRANCH" == "[DEFINIR"* || "$INTEGRATION_BRANCH" == "[DEFINIR"* ]]; then
  echo "PROD_BRANCH/INTEGRATION_BRANCH não configurados — rode /setup" >&2
  exit 1
fi

# Avisa em stderr (sem bloquear) se produção tem commits fora da integração —
# release-postmerge.sh pendente ou hotfix direto; sem `git fetch`, para não pôr rede em todo comando.
if git rev-parse --verify -q "origin/$PROD_BRANCH" >/dev/null && git rev-parse --verify -q "origin/$INTEGRATION_BRANCH" >/dev/null; then
  if ! git merge-base --is-ancestor "origin/$PROD_BRANCH" "origin/$INTEGRATION_BRANCH" 2>/dev/null; then
    echo "⚠️ origin/$PROD_BRANCH tem commits que origin/$INTEGRATION_BRANCH não tem — se um release foi mergeado recentemente, rode .github/scripts/release-postmerge.sh (encerramento do /release)." >&2
  fi
fi

echo "PROD_BRANCH=$PROD_BRANCH"
echo "INTEGRATION_BRANCH=$INTEGRATION_BRANCH"
