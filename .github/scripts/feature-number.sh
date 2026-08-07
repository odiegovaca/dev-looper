#!/usr/bin/env bash
# feature-number.sh
#
# Extrai {N} da branch atual, no padrão {tipo}/{N}-nome-descritivo criado
# pelo /code (ex: feature/42-checkout-pix → 42). Esse número é o
# identificador comum entre spec, issue, review e fix-review — centralizado
# aqui para /review e /fix-review não duplicarem o mesmo regex.
set -euo pipefail

BRANCH="$(git branch --show-current)"
N="$(echo "$BRANCH" | sed -E 's#^[a-z]+/([0-9]+)-.*#\1#')"

if [[ -z "$N" || "$N" == "$BRANCH" ]]; then
  echo "Branch '$BRANCH' não segue o padrão {tipo}/{N}-nome-descritivo — não foi possível extrair {N}" >&2
  exit 1
fi

echo "$N"
