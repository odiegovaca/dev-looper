#!/usr/bin/env bash
# changed-files.sh <branch_integracao>
# Lista, uma linha por arquivo, os arquivos alterados desde o merge-base com a
# branch de integração. Sem default para a branch — o valor tem dono
# (release-branches.sh), e um default aqui compararia contra a branch errada em silêncio.
set -euo pipefail

INTEGRATION_BRANCH="${1:-}"
[ -n "$INTEGRATION_BRANCH" ] || {
  echo "Uso: changed-files.sh <branch_integracao> — o valor vem de .github/scripts/release-branches.sh" >&2
  exit 1
}

git fetch origin "$INTEGRATION_BRANCH" --quiet
MERGE_BASE="$(git merge-base HEAD "origin/$INTEGRATION_BRANCH")"
git diff --name-only "$MERGE_BASE"..HEAD
