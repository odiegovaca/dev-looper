#!/usr/bin/env bash
# review-finalize.sh <relatório.md> <data>
#
# Recompõe o relatório de /review na ordem final Summary → Análise por Arquivo →
# Recomendações, a partir do arquivo bruto com os blocos "#### Problema {i} — {SEVERIDADE}".
# Termina imprimindo o sumário pronto para o chat — usar a saída sem alterações.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPORT="${1:-}"
DATA="${2:-}"
if [ -z "$REPORT" ] || [ -z "$DATA" ]; then
  echo "Uso: review-finalize.sh <relatório.md> <data>" >&2
  exit 1
fi
if [ ! -f "$REPORT" ]; then
  echo "Relatório não encontrado: $REPORT — é o passo 2 do /review que o escreve, com um bloco '#### Problema {i} — {SEVERIDADE}' por achado" >&2
  exit 1
fi

STATS="$("$SCRIPT_DIR/review-stats.sh" "$REPORT")"
while IFS='=' read -r key value; do
  case "$key" in
    CRITICAL_COUNT) CRITICAL_COUNT="$value" ;;
    HIGH_COUNT)     HIGH_COUNT="$value" ;;
    MEDIUM_COUNT)   MEDIUM_COUNT="$value" ;;
    LOW_COUNT)      LOW_COUNT="$value" ;;
    VEREDITO)       VEREDITO="$value" ;;
  esac
done <<< "$STATS"

# Numa reexecução o arquivo já está na ordem final: recupera só a análise, senão
# o relatório inteiro entraria dentro dela, uma camada por rodada.
if grep -q '^## Análise por Arquivo$' "$REPORT"; then
  ANALISE="$(awk '
    /^## Análise por Arquivo$/ { found = 1; next }
    found && /^## Recomendações$/ { exit }
    found { print }
  ' "$REPORT" | sed -e '/./,$!d')"
else
  ANALISE="$(cat "$REPORT")"
fi

POS_FIX="$(awk '/^## Pós-fix$/ { found = 1 } found { print }' "$REPORT")"

# Recomendações são 100% derivadas dos blocos "Problema":
# Must Have (bloqueantes) = CRITICAL + HIGH, Should Have = MEDIUM, Nice to Have = LOW.
MUST_HAVE="$(grep -oE '^#### Problema [0-9]+ — (CRITICAL|HIGH)$' "$REPORT" | sed 's/^#### /- /' || true)"
SHOULD_HAVE="$(grep -oE '^#### Problema [0-9]+ — MEDIUM$' "$REPORT" | sed 's/^#### /- /' || true)"
NICE_TO_HAVE="$(grep -oE '^#### Problema [0-9]+ — LOW$' "$REPORT" | sed 's/^#### /- /' || true)"

{
  echo "## Summary"
  echo
  echo "**Data:** $DATA"
  echo
  echo "**Estatísticas:** $CRITICAL_COUNT critical, $HIGH_COUNT high, $MEDIUM_COUNT medium, $LOW_COUNT low"
  echo
  echo "**Veredito:** $VEREDITO"
  echo
  echo "## Análise por Arquivo"
  echo
  echo "$ANALISE"
  echo
  echo "## Recomendações"
  echo
  echo "### Must Have (bloqueantes)"
  echo
  echo "${MUST_HAVE:-- Nenhum.}"
  echo
  echo "### Should Have"
  echo
  echo "${SHOULD_HAVE:-- Nenhum.}"
  echo
  echo "### Nice to Have"
  echo
  echo "${NICE_TO_HAVE:-- Nenhum.}"
  if [ -n "$POS_FIX" ]; then
    echo
    echo "$POS_FIX"
  fi
} > "$REPORT"

PROXIMOS_PASSOS="$("$SCRIPT_DIR/next-step.sh" "$VEREDITO")"

echo "## Code Review Completo"
echo
echo "**Relatório:** \`$REPORT\`"
echo "**Problemas:** $CRITICAL_COUNT critical, $HIGH_COUNT high, $MEDIUM_COUNT medium, $LOW_COUNT low"
echo
echo "### Veredito"
echo
echo "$VEREDITO"
echo
echo "### Próximos Passos"
echo
echo "$PROXIMOS_PASSOS"
