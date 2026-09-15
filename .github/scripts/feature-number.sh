#!/usr/bin/env bash
# feature-number.sh
#
# Extrai {N} da branch atual, no padrão {tipo}/{N}-nome-descritivo
# (ex: feature/42-checkout-pix → 42) — o identificador comum entre spec,
# issue e review. Falha com exit 1 se a branch não segue o padrão.
set -euo pipefail

BRANCH="$(git branch --show-current)"
N="$(echo "$BRANCH" | sed -E 's#^[a-z]+/([0-9]+)-.*#\1#')"

if [[ -z "$N" || "$N" == "$BRANCH" ]]; then
  echo "Branch '$BRANCH' não segue o padrão {tipo}/{N}-nome-descritivo ({N} = número da issue) — rode /code para criar a branch da issue, ou renomeie a atual (git branch -m feature/{N}-nome-descritivo)" >&2
  exit 1
fi

echo "$N"
