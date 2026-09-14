#!/usr/bin/env bash
# fix-review-select.sh <relatório.md> <seletor>...
#
# Resolve os seletores do /fix-review nos problemas a corrigir. Seletor é
# número, severidade (atalho para os números dela) ou `todos`, combináveis em
# qualquer ordem — o conjunto é a união de tudo que casar. Imprime SELECIONADOS
# e IGNORADOS, cada problema com severidade e Local.
#
# Existe para o passo da seleção não ser prosa que o agente tem de honrar:
# severidade escrita errada é erro em vez de seleção vazia silenciosa, número
# fora do relatório é aviso em vez de interrupção, e Arquivo Protegido sai da
# lista antes de alguém abrir o arquivo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAB="$(printf '\t')"

REPORT="${1:-}"
if [ -z "$REPORT" ] || [ ! -f "$REPORT" ] || [ "$#" -lt 2 ]; then
  echo 'Uso: fix-review-select.sh <relatório.md> <seletor>...  (número, critical|high|medium|low, ou todos)' >&2
  exit 1
fi
shift

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

# Problema protegido é motivo para seguir ao passo 5 mesmo sem nada a aplicar:
# é lá que a dispensa é registrada, e sem ela o /status ficaria recomendando
# /fix-review para um problema que ninguém pode corrigir. Só número inventado,
# não: aí não há o que fazer nem o que registrar.
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
