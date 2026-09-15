#!/usr/bin/env bash
# review-stats.sh <relatório.md>
#
# Conta os problemas de um relatório de /review por severidade e deriva o veredito.
# Imprime CRITICAL_COUNT/HIGH_COUNT/MEDIUM_COUNT/LOW_COUNT/VEREDITO em KEY=value.
# Aborta se algum bloco ficou sem severidade reconhecida, em vez de contar errado.
set -euo pipefail

REPORT="${1:-}"
[ -n "$REPORT" ] || { echo "Uso: review-stats.sh <relatório.md>" >&2; exit 1; }
[ -f "$REPORT" ] || { echo "Relatório não encontrado: $REPORT — rode /review para gerá-lo" >&2; exit 1; }

CRITICAL_COUNT=$(grep -c '^#### Problema .* — CRITICAL$' "$REPORT" || true)
HIGH_COUNT=$(grep -c '^#### Problema .* — HIGH$' "$REPORT" || true)
MEDIUM_COUNT=$(grep -c '^#### Problema .* — MEDIUM$' "$REPORT" || true)
LOW_COUNT=$(grep -c '^#### Problema .* — LOW$' "$REPORT" || true)
TOTAL_COUNT=$(grep -c '^#### Problema ' "$REPORT" || true)

SUM=$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))
if [ "$TOTAL_COUNT" -ne "$SUM" ]; then
  echo "Inconsistência em $REPORT: $TOTAL_COUNT blocos '#### Problema' mas só $SUM com severidade reconhecida (CRITICAL/HIGH/MEDIUM/LOW) — corrigir o formato do problema antes de prosseguir" >&2
  exit 1
fi

if [ "$CRITICAL_COUNT" -gt 0 ]; then
  VEREDITO="REPROVADO"
elif [ "$HIGH_COUNT" -gt 0 ]; then
  VEREDITO="APROVADO COM RESSALVAS"
else
  VEREDITO="APROVADO"
fi

echo "CRITICAL_COUNT=$CRITICAL_COUNT"
echo "HIGH_COUNT=$HIGH_COUNT"
echo "MEDIUM_COUNT=$MEDIUM_COUNT"
echo "LOW_COUNT=$LOW_COUNT"
echo "VEREDITO=$VEREDITO"
