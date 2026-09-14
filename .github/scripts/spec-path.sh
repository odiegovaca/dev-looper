#!/usr/bin/env bash
# spec-path.sh <título da funcionalidade ou caminho de uma spec>
#
# Resolve em qual arquivo o /spec vai escrever, e com que datas.
# Imprime MODO (nova|refinamento|conflito), SPEC_PATH, DATA_ARQUIVO e DATA_CAMPO
# em KEY=value; em `conflito` acrescenta CANDIDATAS com as specs que já usam o
# identificador. Num refinamento o nome do arquivo não muda — a data dele é a de
# criação, e é ela que mantém a ordem cronológica da pasta.
set -euo pipefail

ARG="${1:-}"
[ -n "$ARG" ] || { echo "Uso: spec-path.sh <título da funcionalidade ou caminho de uma spec>" >&2; exit 1; }

DATA_ARQUIVO="$(date +%F)"
DATA_CAMPO="$(date +%d/%m/%Y)"

emit() {
  echo "MODO=$1"
  echo "SPEC_PATH=$2"
  echo "DATA_ARQUIVO=$DATA_ARQUIVO"
  echo "DATA_CAMPO=$DATA_CAMPO"
}

# Caminho de arquivo existente entra direto como refinamento.
if [ -f "$ARG" ]; then
  emit refinamento "$ARG"
  exit 0
fi

# Argumento com cara de caminho que não existe é refinamento que errou o alvo,
# nunca título de spec nova — criar aqui silenciaria o engano.
case "$ARG" in
  */* | *.md)
    echo "Spec não encontrada: $ARG — confira o caminho. Specs em docs/issues/:" >&2
    ls docs/issues/spec-*.md 2>/dev/null | sed 's|^|  |' >&2 || echo "  (nenhuma)" >&2
    exit 1
    ;;
esac

# Identificador kebab-case: transliteração para ASCII, fora os acentos que o
# iconv deixa como caractere solto, e todo o resto vira "-".
ID="$(printf '%s' "$ARG" \
  | { iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || cat; } \
  | tr '[:upper:]' '[:lower:]' \
  | sed -e 's/[~^`'"'"'"]//g' -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//')"

[ -n "$ID" ] || { echo "Não consegui derivar um identificador de '$ARG' — passe um título com letras ou números" >&2; exit 1; }

# O identificador é a chave da spec: mesma feature, mesmo arquivo, qualquer que
# seja a data. Sem isto, refinar uma spec de ontem criaria uma segunda de hoje.
EXISTENTES="$(ls docs/issues/spec-[0-9]*-"$ID".md 2>/dev/null || true)"
QUANTAS="$(printf '%s' "$EXISTENTES" | grep -c . || true)"

if [ "$QUANTAS" -eq 1 ]; then
  emit refinamento "$EXISTENTES"
elif [ "$QUANTAS" -gt 1 ]; then
  emit conflito ""
  echo "CANDIDATAS:"
  printf '%s\n' "$EXISTENTES"
else
  emit nova "docs/issues/spec-${DATA_ARQUIVO}-${ID}.md"
fi
