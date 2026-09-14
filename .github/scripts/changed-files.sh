#!/usr/bin/env bash
# changed-files.sh <branch_integracao>
# Lista, uma linha por arquivo, os arquivos alterados desde o merge-base com a
# branch de integração. Sem default: um default aqui seria uma segunda cópia do
# valor que o release-branches.sh é dono, comparando contra a branch errada em
# silêncio no projeto em que ela não bate.
set -euo pipefail

INTEGRATION_BRANCH="${1:-}"
[ -n "$INTEGRATION_BRANCH" ] || {
  echo "Uso: changed-files.sh <branch_integracao> — o valor vem de .github/scripts/release-branches.sh" >&2
  exit 1
}

git fetch origin "$INTEGRATION_BRANCH" --quiet
MERGE_BASE="$(git merge-base HEAD "origin/$INTEGRATION_BRANCH")"
git diff --name-only "$MERGE_BASE"..HEAD
