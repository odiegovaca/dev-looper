#!/usr/bin/env bash
# fix-review-select.sh <seletor>...
#
# Resolve os seletores do /fix-review nos problemas a corrigir, no relatório mais
# recente da feature. Seletor é número, severidade ou `todos`, combináveis em
# qualquer ordem — o conjunto é a união. Imprime SELECIONADOS e IGNORADOS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAB="$(printf '\t')"

if [ "$#" -lt 1 ]; then
  echo 'Uso: fix-review-select.sh <seletor>...  (número, critical|high|medium|low, ou todos)' >&2
  exit 1
fi

REPORT="$("$SCRIPT_DIR/latest-review.sh")"

PROBLEMS="$("$SCRIPT_DIR/review-problems.sh" "$REPORT")"

info_of() {
  awk -F"$TAB" -v n="$1" '$1 == n { print; exit }' <<< "$PROBLEMS"
}

PEDIDOS=""
DESCONHECIDOS=""
for sel in "$@"; do
  alvo="$(tr '[:upper:]' '[:lower:]' <<< "${sel#\#}")"
  alvo="${alvo%,}"
  case "$alvo" in
    todos)
      PEDIDOS="$PEDIDOS $(awk -F"$TAB" '{ print $1 }' <<< "$PROBLEMS" | tr '\n' ' ')"
      ;;
    critical | high | medium | low)
      SEV="$(tr '[:lower:]' '[:upper:]' <<< "$alvo")"
      PEDIDOS="$PEDIDOS $(awk -F"$TAB" -v s="$SEV" '$2 == s { print $1 }' <<< "$PROBLEMS" | tr '\n' ' ')"
      ;;
    '' | *[!0-9]*)
      echo "Seletor inválido: '$sel' — use número, critical, high, medium, low ou todos." >&2
      exit 1
      ;;
    *)
      if [ -n "$(info_of "$alvo")" ]; then
        PEDIDOS="$PEDIDOS $alvo"
      else
        DESCONHECIDOS="$DESCONHECIDOS $alvo"
      fi
      ;;
  esac
done

SELECIONADOS=""
IGNORADOS=""
PROTEGIDOS=""
for n in $(tr ' ' '\n' <<< "$PEDIDOS" | grep -E '^[0-9]+$' | sort -n -u || true); do
  IFS="$TAB" read -r num sev local protegido <<< "$(info_of "$n")"
  if [ -n "$protegido" ]; then
    PROTEGIDOS="$PROTEGIDOS $num"
    IGNORADOS="$IGNORADOS  #$num ($sev) ${local:-sem Local} — arquivo protegido, só /setup e /lesson podem alterá-lo
"
  else
    SELECIONADOS="$SELECIONADOS  #$num ($sev) ${local:-sem Local}
"
  fi
done

for n in $(tr ' ' '\n' <<< "$DESCONHECIDOS" | grep -E '^[0-9]+$' | sort -n -u || true); do
  IGNORADOS="$IGNORADOS  #$n — não existe no relatório
"
done

# Problema protegido segue para a finalização mesmo sem nada a aplicar — é lá que
# a dispensa fica registrada. Só número inventado não: não há o que registrar.
if [ -z "$SELECIONADOS" ] && [ -z "$PROTEGIDOS" ]; then
  echo "Nenhum problema casou com os seletores em $REPORT — rode /fix-review com um número ou uma severidade presentes no relatório (ou 'todos')." >&2
  [ -n "$IGNORADOS" ] && printf '%s' "$IGNORADOS" >&2
  exit 1
fi

echo "SELECIONADOS:"
printf '%s' "${SELECIONADOS:-  nenhum
}"
if [ -n "$IGNORADOS" ]; then
  echo "IGNORADOS:"
  printf '%s' "$IGNORADOS"
fi
