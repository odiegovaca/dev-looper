#!/usr/bin/env bash
# hoje.sh [formato]
#
# Imprime a data no formato do `date` (padrão %F), deslocando o UTC em
# DEV_LOOPER_UTC_OFFSET horas (padrão -3, Brasília) em vez de ler o relógio do
# sistema — assim o PC e uma sessão de nuvem em UTC datam a mesma spec igual.
# Deslocamento fixo, e não TZ=, que falha em silêncio onde falta tzdata (Git Bash).
set -euo pipefail

OFFSET="${DEV_LOOPER_UTC_OFFSET:--3}"

if ! printf '%s' "$OFFSET" | grep -qE '^[+-]?(0|[1-9]|1[0-4])$'; then
  echo "DEV_LOOPER_UTC_OFFSET inválido: '$OFFSET' — use horas inteiras de -14 a +14 (ex.: -3 para Brasília)" >&2
  exit 1
fi

date -u -d "$OFFSET hours" "+${1:-%F}"
