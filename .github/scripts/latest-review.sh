#!/usr/bin/env bash
# latest-review.sh
#
# Localiza o relatório de /review mais recente da feature atual (ordenação
# numérica por {seq}, não por mtime — não confiável após clone/checkout).
# Único lugar que faz essa busca: o review-prepare.sh a usa para saber o {seq}
# da próxima rodada e o status-snapshot.sh para mostrar o último review, em vez
# de cada um repetir a ordenação. Falha com exit 1 e mensagem no stderr se a
# branch não seguir o padrão esperado ou não houver nenhum review para a
# feature — os dois chamam com `|| true` quando a ausência é normal.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

N="$("$SCRIPT_DIR/feature-number.sh")"
LATEST="$(ls "docs/reviews/review-${N}-"*.md 2>/dev/null | sort -V | tail -1 || true)"

if [ -z "$LATEST" ]; then
  echo "Nenhum review encontrado para a feature ${N} — rode /review antes." >&2
  exit 1
fi

echo "$LATEST"
