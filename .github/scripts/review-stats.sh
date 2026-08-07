#!/usr/bin/env bash
# review-stats.sh <relatório.md>
#
# Conta problemas por severidade num relatório gerado por /review (blocos
# "#### Problema {i} — {SEVERIDADE}") e deriva o veredito. Valida que a soma
# das quatro severidades bate com o total de blocos — aborta com erro se
# algum problema não seguiu o formato esperado, em vez de silenciosamente
# reportar uma contagem errada.
#
# Imprime CRITICAL_COUNT/HIGH_COUNT/MEDIUM_COUNT/LOW_COUNT/VEREDITO, uma
# variável por linha (mesma convenção do status-snapshot.sh).
set -euo pipefail

REPORT="${1:-}"
[ -n "$REPORT" ] && [ -f "$REPORT" ] || { echo "Uso: review-stats.sh <relatório.md>" >&2; exit 1; }

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
