#!/usr/bin/env bash
# changed-files.sh [branch_integracao]
# Lista, uma linha por arquivo, os arquivos alterados desde o merge-base com a
# branch de integração (padrão: develop).
set -euo pipefail

INTEGRATION_BRANCH="${1:-develop}"

git fetch origin "$INTEGRATION_BRANCH" --quiet
MERGE_BASE="$(git merge-base HEAD "origin/$INTEGRATION_BRANCH")"
git diff --name-only "$MERGE_BASE"..HEAD
