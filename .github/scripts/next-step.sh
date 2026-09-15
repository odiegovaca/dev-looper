#!/usr/bin/env bash
# next-step.sh <veredito> [status-pós-fix] [bloqueantes-pendentes]
#
# Imprime a sugestão de próximo passo do ciclo de review. Dono único da tabela —
# /review, /fix-review e /status chamam daqui em vez de cada um repetir a regra.
# O status pós-fix, quando informado, vence o veredito: é o retrato mais recente.
set -euo pipefail

VEREDITO="${1:-}"
STATUS_POS_FIX="${2:-}"
BLOQUEANTES="${3:-}"

case "$STATUS_POS_FIX" in
  bloqueado)
    # Números crus porque é o comando que o usuário vai digitar (o seletor aceita as duas formas).
    echo "/fix-review ${BLOQUEANTES} — bloqueantes ainda pendentes."
    exit 0
    ;;
  revisar)
    echo "/review — bloqueante corrigido pelo /fix-review, revalidar antes de seguir para /rc."
    exit 0
    ;;
  liberado)
    echo "/rc — correções aplicadas e nenhum bloqueante pendente."
    exit 0
    ;;
esac

case "$VEREDITO" in
  APROVADO)                 echo "/rc — review aprovado, sem problemas bloqueantes." ;;
  "APROVADO COM RESSALVAS") echo "/fix-review high — review com ressalvas, corrigir antes de /rc." ;;
  REPROVADO)                echo "/fix-review critical high — review reprovado, corrigir os bloqueantes." ;;
  *)                        echo "/review — veredito do último review não reconhecido (formato mudou?)." ;;
esac
