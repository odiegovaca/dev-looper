#!/usr/bin/env bash
# status-snapshot.sh — agrega versão, cobertura, specs e último review da
# feature atual numa única chamada, para o /status interpretar e formatar.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "VERSION=$("$SCRIPT_DIR/bump-version.sh" current 2>/dev/null || echo "desconhecida")"
echo "COVERAGE=$("$SCRIPT_DIR/coverage.sh" 2>/dev/null || echo "não disponível")"

echo "SPECS:"
ls docs/issues/spec-*.md 2>/dev/null || true

N="$(git branch --show-current | sed -E 's#^[a-z]+/([0-9]+)-.*#\1#')"
if [[ "$N" =~ ^[0-9]+$ ]]; then
  LATEST_REVIEW="$(ls "docs/reviews/review-${N}-"*.md 2>/dev/null | sort -V | tail -1)"
  echo "LATEST_REVIEW=${LATEST_REVIEW:-nenhum}"
else
  echo "LATEST_REVIEW=nenhum"
fi
