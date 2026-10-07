#!/usr/bin/env bash
# review-finalize.sh <relatório.md> <data> <escopo> <base>
#
# Recompõe o relatório de /dl-review na ordem final Summary → Análise por Arquivo →
# Recomendações → Fora do escopo, a partir do arquivo bruto com os blocos
# "#### Problema {i} — {SEVERIDADE}". O Summary registra o escopo e o commit
# revisado, de onde o review seguinte parte. Termina imprimindo o sumário pronto
# para o chat — usar a saída sem alterações.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPORT="${1:-}"
DATA="${2:-}"
ESCOPO="${3:-}"
BASE="${4:-}"
if [ -z "$REPORT" ] || [ -z "$DATA" ] || [ -z "$ESCOPO" ] || [ -z "$BASE" ]; then
  echo "Uso: review-finalize.sh <relatório.md> <data> <escopo> <base> — os quatro valores saem do review-prepare.sh" >&2
  exit 1
fi
if [ ! -f "$REPORT" ]; then
  echo "Relatório não encontrado: $REPORT — é o passo 2 do /dl-review que o escreve, com um bloco '#### Problema {i} — {SEVERIDADE}' por achado" >&2
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

# "Fora do escopo" vai do título até a próxima seção, no bruto e na reexecução.
# Os blocos dela não começam com "#### Problema", então não entram na contagem.
FORA="$(awk '
  /^## Fora do escopo$/ { found = 1; print; next }
  found && /^## / { exit }
  found { print }
' "$REPORT")"

# Numa reexecução o arquivo já está na ordem final: recupera só a análise, senão
# o relatório inteiro entraria dentro dela, uma camada por rodada. O commit
# revisado também fica o da primeira execução, que é o que o review leu.
REVISADO=""
if grep -q '^## Análise por Arquivo$' "$REPORT"; then
  ANALISE="$(awk '
    /^## Análise por Arquivo$/ { found = 1; next }
    found && /^## Recomendações$/ { exit }
    found { print }
  ' "$REPORT" | sed -e '/./,$!d')"
  REVISADO="$(grep -m1 '^\*\*Commit revisado:\*\*' "$REPORT" | grep -oE '[0-9a-f]{7,40}' | head -1 || true)"
else
  ANALISE="$(awk '
    /^## Fora do escopo$/ { skip = 1; next }
    skip && /^## / { skip = 0 }
    !skip { print }
  ' "$REPORT")"
fi
[ -n "$REVISADO" ] || REVISADO="$(git rev-parse HEAD)"

case "$ESCOPO" in
  completo)    ESCOPO_LINHA="completo, desde \`$(git rev-parse --short "$BASE")\` (merge-base com a branch de integração)" ;;
  incremental) ESCOPO_LINHA="incremental, desde \`$(git rev-parse --short "$BASE")\` (o commit revisado pelo review anterior)" ;;
  *) echo "Escopo '$ESCOPO' desconhecido — use o ESCOPO do review-prepare.sh (completo ou incremental)" >&2; exit 1 ;;
esac

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
  echo "**Escopo:** $ESCOPO_LINHA"
  echo
  echo "**Commit revisado:** \`$REVISADO\`"
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
  if [ -n "$FORA" ]; then
    echo
    echo "$FORA"
  fi
  if [ -n "$POS_FIX" ]; then
    echo
    echo "$POS_FIX"
  fi
} > "$REPORT"

PROXIMOS_PASSOS="$("$SCRIPT_DIR/next-step.sh" "$VEREDITO" "" "" "$REPORT")"

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
