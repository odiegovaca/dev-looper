#!/usr/bin/env bash
# latest-review.sh
#
# Imprime o caminho do relatório de /review mais recente da feature atual, ou
# falha com exit 1 se não houver — ordena por {seq}, não por mtime (não sobrevive a clone).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

N="$("$SCRIPT_DIR/feature-number.sh")"
LATEST="$(ls "docs/reviews/review-${N}-"*.md 2>/dev/null | sort -V | tail -1 || true)"

if [ -z "$LATEST" ]; then
  echo "Nenhum review encontrado para a feature ${N} — rode /review antes." >&2
  exit 1
fi

echo "$LATEST"
