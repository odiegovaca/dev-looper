#!/usr/bin/env bash
# latest-review.sh
#
# Localiza o relatório de /review mais recente da feature atual (ordenação
# numérica por {seq}, não por mtime — não confiável após clone/checkout).
# Centraliza a mesma lógica hoje duplicada entre review-prepare.sh e
# status-snapshot.sh. Falha com exit 1 e mensagem no stderr se a branch não
# seguir o padrão esperado ou não houver nenhum review para a feature.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

N="$("$SCRIPT_DIR/feature-number.sh")"
LATEST="$(ls "docs/reviews/review-${N}-"*.md 2>/dev/null | sort -V | tail -1 || true)"

if [ -z "$LATEST" ]; then
  echo "Nenhum review encontrado para a feature ${N} — rode /review antes." >&2
  exit 1
fi

echo "$LATEST"
