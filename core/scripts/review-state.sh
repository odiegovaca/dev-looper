#!/usr/bin/env bash
# review-state.sh
#
# Imprime o estado do ciclo de review da feature atual, lido do relatório mais
# recente, em KEY=value: REPORT, VEREDITO, STATUS_POS_FIX, BLOQUEANTES, DATA e
# STATS. Os valores têm espaço, então ler com `while IFS='=' read`, não com eval.
# Sem relatório, REPORT sai vazio e o resto também. Lê o que o review-finalize.sh
# e o fix-review-finalize.sh já gravaram, em vez de reparsear os blocos.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPORT="$("$SCRIPT_DIR/latest-review.sh" 2>/dev/null || true)"

# campo <rótulo> — valor da primeira linha "**<rótulo>:** valor" do relatório.
# `|| true` para relatório em formato antigo sair com o campo vazio.
campo() {
  grep -m1 "^\*\*$1:\*\*" "$REPORT" | sed -E "s/^\*\*$1:\*\*[[:space:]]*//" || true
}

VEREDITO=""
STATUS_POS_FIX=""
BLOQUEANTES=""
DATA=""
STATS=""
if [ -n "$REPORT" ] && [ -f "$REPORT" ]; then
  VEREDITO="$(campo Veredito)"
  STATUS_POS_FIX="$(campo 'Status pós-fix')"
  # Escrita pelo fix-review-finalize.sh; sem ela o next-step.sh sugeriria "/dl-fix"
  # sem seletor. "nenhum" é o vazio no relatório, e volta a ser vazio aqui.
  BLOQUEANTES="$(campo 'Bloqueantes pendentes')"
  [ "$BLOQUEANTES" != "nenhum" ] || BLOQUEANTES=""
  DATA="$(campo Data)"
  STATS="$(campo 'Estatísticas')"
fi

echo "REPORT=$REPORT"
echo "VEREDITO=$VEREDITO"
echo "STATUS_POS_FIX=$STATUS_POS_FIX"
echo "BLOQUEANTES=$BLOQUEANTES"
echo "DATA=$DATA"
echo "STATS=$STATS"
