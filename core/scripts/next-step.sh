#!/usr/bin/env bash
# next-step.sh <veredito> [status-pós-fix] [bloqueantes-pendentes] [relatório]
#
# Imprime a sugestão de próximo passo do ciclo de review. Dono único da tabela —
# /dl-review, /dl-fix e /dl-status chamam daqui em vez de cada um repetir a regra.
# O status pós-fix, quando informado, vence o veredito: é o retrato mais recente.
#
# Com o relatório informado, vale o teto de rodadas: o {seq} dele diz quantas
# rodadas de /dl-fix já foram revisadas, e passado o teto a sugestão de mais um
# /dl-fix vira "⛔ Teto", o sinal para parar e chamar o usuário.
set -euo pipefail

VEREDITO="${1:-}"
STATUS_POS_FIX="${2:-}"
BLOQUEANTES="${3:-}"
REPORT="${4:-}"

# Rodadas de /dl-fix revisadas antes de o ciclo parar. Cada rodada é um fix e o
# review dele, então o relatório {seq} vem depois de {seq}-1 rodadas.
TETO_RODADAS=2

SEQ="$(sed -nE 's#.*review-[0-9]+-([0-9]+)\.md$#\1#p' <<< "$REPORT")"

# Imprime a sugestão de /dl-fix, ou o teto se as rodadas acabaram.
fix() {
  if [ -n "$SEQ" ] && [ $((SEQ - 1)) -ge "$TETO_RODADAS" ]; then
    echo "⛔ Teto: $TETO_RODADAS rodadas de /dl-fix sem liberado — parar e chamar o usuário. O problema provavelmente está na spec ou no desenho, não em mais uma correção."
  else
    echo "$1"
  fi
}

case "$STATUS_POS_FIX" in
  bloqueado)
    # Números crus porque é o comando que o usuário vai digitar (o seletor aceita as duas formas).
    fix "/dl-fix ${BLOQUEANTES} — bloqueantes ainda pendentes."
    exit 0
    ;;
  revisar)
    echo "/dl-review — bloqueante corrigido pelo /dl-fix, revalidar antes de seguir para /dl-rc."
    exit 0
    ;;
  liberado)
    echo "/dl-rc — correções aplicadas e nenhum bloqueante pendente."
    exit 0
    ;;
esac

case "$VEREDITO" in
  APROVADO)                 echo "/dl-rc — review aprovado, sem problemas bloqueantes." ;;
  "APROVADO COM RESSALVAS") fix "/dl-fix high — review com ressalvas, corrigir antes de /dl-rc." ;;
  REPROVADO)                fix "/dl-fix critical high — review reprovado, corrigir os bloqueantes." ;;
  *)                        echo "/dl-review — veredito do último review não reconhecido (formato mudou?)." ;;
esac
