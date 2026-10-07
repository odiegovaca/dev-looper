#!/usr/bin/env bash
# review-prepare.sh [--completo] [branch-de-integração]
#
# Resolve tudo que o /dl-review precisa antes de analisar: escopo, arquivos
# alterados (sem lockfiles e reviews anteriores), {N} da feature, próximo {seq},
# data e caminho do relatório. Falha com exit 1 se não houver o que revisar.
#
# O escopo sai do review anterior da feature. Se ele registrou o commit que
# revisou, e esse commit está na história do HEAD, o review é `incremental`: lê
# só o que mudou desde então (no ciclo normal, o fix). Senão, ou com --completo,
# é `completo`: tudo desde o merge-base com a branch de integração.
#
# Imprime N/SEQ/DATA/REPORT/ESCOPO/BASE em KEY=value (mais REVIEW_ANTERIOR no
# incremental), seguido de "DIFF:" e o diff dos arquivos alterados desde BASE
# (cada um delimitado pelo próprio "diff --git").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMPLETO=false
INTEGRATION_BRANCH=""
for arg in "$@"; do
  case "$arg" in
    --completo) COMPLETO=true ;;
    -*) echo "Argumento desconhecido: $arg — uso: review-prepare.sh [--completo] [branch-de-integração]" >&2; exit 1 ;;
    *) INTEGRATION_BRANCH="$arg" ;;
  esac
done

N="$("$SCRIPT_DIR/feature-number.sh")"
mkdir -p docs/reviews
# Daqui sai só o próximo {seq}; quem ordena os relatórios é o latest-review.sh.
LAST_REPORT="$("$SCRIPT_DIR/latest-review.sh" 2>/dev/null || true)"
LAST_SEQ="$(sed -E "s#.*review-${N}-([0-9]+)\.md#\1#" <<< "$LAST_REPORT")"
SEQ=$(( ${LAST_SEQ:-0} + 1 ))
DATA=$("$SCRIPT_DIR/hoje.sh" %Y-%m-%d-%H%M%S)
REPORT="docs/reviews/review-${N}-${SEQ}.md"

# Relatório de antes desta regra não tem o commit, e cai no completo.
ESCOPO=completo
BASE=""
if [ "$COMPLETO" = false ] && [ -n "$LAST_REPORT" ]; then
  REVISADO="$(grep -m1 '^\*\*Commit revisado:\*\*' "$LAST_REPORT" | grep -oE '[0-9a-f]{7,40}' | head -1 || true)"
  if [ -n "$REVISADO" ]; then
    if [ "$(git rev-parse HEAD)" = "$(git rev-parse "$REVISADO" 2>/dev/null || true)" ]; then
      echo "Nada commitado desde o commit revisado por $LAST_REPORT — commite o fix antes do /dl-review, ou rode /dl-review --completo para revisar a branch inteira de novo." >&2
      exit 1
    elif git merge-base --is-ancestor "$REVISADO" HEAD 2>/dev/null; then
      ESCOPO=incremental
      BASE="$REVISADO"
    else
      # Rebase ou amend reescreveram a história: o diff desde o commit não diria nada.
      echo "⚠️ O commit revisado por $LAST_REPORT ($REVISADO) não está mais na história da branch — revisando a branch inteira." >&2
    fi
  fi
fi

if [ "$ESCOPO" = completo ]; then
  # Sem argumento, usa a branch de integração do projeto.
  if [ -z "$INTEGRATION_BRANCH" ]; then
    BRANCHES="$("$SCRIPT_DIR/release-branches.sh")" || exit 1
    eval "$BRANCHES"
  fi
  if ! RAW_CHANGED_FILES="$("$SCRIPT_DIR/changed-files.sh" "$INTEGRATION_BRANCH")"; then
    echo "Falha ao obter arquivos alterados em relação a $INTEGRATION_BRANCH — rode 'git fetch origin $INTEGRATION_BRANCH' e, se a branch não existir no remoto, confira INTEGRATION_BRANCH em {{SCRIPTS_DIR}}/release-branches.sh" >&2
    exit 1
  fi
  BASE="$(git merge-base HEAD "origin/$INTEGRATION_BRANCH")"
  VAZIO="Nenhuma mudança em relação a $INTEGRATION_BRANCH — nada para revisar. Commite a implementação (/dl-code) antes de rodar o /dl-review."
else
  RAW_CHANGED_FILES="$(git diff --name-only "$BASE"..HEAD)"
  VAZIO="Desde o commit revisado por $LAST_REPORT só mudaram lockfiles ou relatórios — nada para revisar."
fi

CHANGED_FILES="$(echo "$RAW_CHANGED_FILES" | grep -vE '^docs/reviews/|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|go\.sum|Gemfile\.lock|poetry\.lock' || true)"

if [ -z "$CHANGED_FILES" ]; then
  echo "$VAZIO" >&2
  exit 1
fi

mapfile -t FILES <<< "$CHANGED_FILES"
DIFF="$(git diff "$BASE..HEAD" -- "${FILES[@]}")"

echo "N=$N"
echo "SEQ=$SEQ"
echo "DATA=$DATA"
echo "REPORT=$REPORT"
echo "ESCOPO=$ESCOPO"
echo "BASE=$BASE"
if [ "$ESCOPO" = incremental ]; then
  echo "REVIEW_ANTERIOR=$LAST_REPORT"
fi
echo "DIFF:"
echo "$DIFF"
