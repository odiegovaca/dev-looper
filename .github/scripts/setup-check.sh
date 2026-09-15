#!/usr/bin/env bash
# setup-check.sh
#
# Lista o que o /setup deixou por configurar: os [DEFINIR] restantes no
# copilot-instructions.md e nos scripts que ele preenche.
# Sempre sai com 0 — é relatório de pendências, não guarda de execução.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTRUCTIONS=".github/copilot-instructions.md"

PENDENTES=0

contar() {
  printf '%s' "$1" | grep -c . || true
}

# Só o marcador com dois-pontos é placeholder; "[DEFINIR" sem eles aparece nas
# guardas que os próprios scripts usam para detectar que não foram configurados.
if [ -f "$INSTRUCTIONS" ]; then
  ACHADOS="$(grep -n '\[DEFINIR:' "$INSTRUCTIONS" || true)"
  QUANTOS="$(contar "$ACHADOS")"
  echo "copilot-instructions.md: $QUANTOS [DEFINIR] pendente(s)"
  [ "$QUANTOS" -eq 0 ] || echo "$ACHADOS" | sed -E 's/^([0-9]+):[[:space:]]*/  linha \1: /' | cut -c1-110
  PENDENTES=$((PENDENTES + QUANTOS))
else
  echo "copilot-instructions.md: não existe — é o passo 4 do /setup que o gera"
  PENDENTES=$((PENDENTES + 1))
fi

echo
echo "Scripts preenchidos pelo /setup:"
for f in bump-version.sh coverage.sh validate.sh release-branches.sh; do
  ACHADOS="$(grep -n '\[DEFINIR:' "$SCRIPT_DIR/$f" || true)"
  QUANTOS="$(contar "$ACHADOS")"
  if [ "$QUANTOS" -eq 0 ]; then
    echo "  ok    $f"
  else
    echo "  FALTA $f — $QUANTOS [DEFINIR]: linhas $(printf '%s' "$ACHADOS" | cut -d: -f1 | tr '\n' ' ')"
    PENDENTES=$((PENDENTES + QUANTOS))
  fi
done

echo
if [ "$PENDENTES" -eq 0 ]; then
  echo "Nenhuma pendência."
else
  echo "$PENDENTES pendência(s) — preencher antes de usar o fluxo."
fi
