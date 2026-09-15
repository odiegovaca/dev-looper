#!/usr/bin/env bash
# spec-status.sh <arquivo.md> [nova|refinamento]
#
# Lê a spec recém-gravada e imprime a confirmação pronta para o chat: status,
# questões em aberto pendentes e o próximo passo que decorre dos dois.
set -euo pipefail

SPEC="${1:-}"
MODO="${2:-}"
[ -n "$SPEC" ] || { echo "Uso: spec-status.sh <arquivo.md> [nova|refinamento]" >&2; exit 1; }
[ -f "$SPEC" ] || { echo "Spec não encontrada: $SPEC — é o passo 2 do /spec que a escreve" >&2; exit 1; }

STATUS="$(grep -m1 '^\*\*Status\*\*:' "$SPEC" | sed -E 's/^\*\*Status\*\*:[[:space:]]*`([^`]+)`.*/\1/' || true)"
ISSUE="$(grep -m1 -E '^\*\*Issue\*\*: \[?#[0-9]+' "$SPEC" | sed -E 's/^\*\*Issue\*\*: \[?#([0-9]+).*/\1/' || true)"

# Contam os itens da seção, não a seção: uma "Questões em Aberto" vazia é zero.
PENDENTES="$(awk '
  /^## Questões em Aberto/ { found = 1; next }
  found && /^## / { exit }
  found && /^- / { n++ }
  END { print n + 0 }
' "$SPEC")"

case "$MODO" in
  nova)        ACAO="criada" ;;
  refinamento) ACAO="atualizada" ;;
  *)           ACAO="gravada" ;;
esac

echo "✅ Spec $ACAO: $SPEC"
echo "   Status: ${STATUS:-ausente} — $PENDENTES questão(ões) em aberto"

if [ "$PENDENTES" -gt 0 ]; then
  echo "   Próximo passo: responda as Questões em Aberto; com a spec aprovada, /issue."
elif [ -n "$ISSUE" ] && [ "$MODO" != "nova" ]; then
  # Spec com issue vinculada e alterada: a issue ficou para trás. Vem antes do
  # teste de Aprovada porque o Status aqui já é `Issue criada`.
  echo "   Próximo passo: /issue — a issue #$ISSUE está com o texto antigo e /issue propaga a spec revisada para ela."
elif [ "$STATUS" = "Aprovada" ] || [ "$STATUS" = "Aprovado" ]; then
  echo "   Próximo passo: /issue para criar a issue GitHub."
else
  echo "   Próximo passo: aprove a spec (Status: \`Aprovada\`) e rode /issue."
fi
