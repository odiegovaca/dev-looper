#!/usr/bin/env bash
# review-problems.sh <relatório.md>
#
# Imprime uma linha por problema do relatório de /review, campos separados por
# TAB: número, severidade, Local (`arquivo:linha`, vazio se o bloco não trouxe)
# e `protegido` quando o arquivo só pode ser alterado por /setup e /lesson.
#
# Único lugar que interpreta o formato do bloco "#### Problema {i} —
# {SEVERIDADE}": a seleção e a finalização do /fix-review leem daqui em vez de
# cada passo refazer o mesmo parse e divergir no primeiro ajuste de formato.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAB="$(printf '\t')"

REPORT="${1:-}"
[ -n "$REPORT" ] || { echo "Uso: review-problems.sh <relatório.md>" >&2; exit 1; }
[ -f "$REPORT" ] || { echo "Relatório não encontrado: $REPORT — rode /review para gerá-lo" >&2; exit 1; }

# Guarda de formato emprestada do review-stats.sh: ele aborta se algum bloco
# ficou sem severidade reconhecida, e é melhor parar aqui do que devolver uma
# lista incompleta que os consumidores tomariam por completa.
"$SCRIPT_DIR/review-stats.sh" "$REPORT" >/dev/null

PROTECTED_GLOBS="$("$SCRIPT_DIR/protected-paths.sh")"

BASE="$(awk -v tab="$TAB" '
  function flush() { if (n != "") print n tab sev tab local }
  /^#### Problema [0-9]+ — [A-Z]+$/ { flush(); n = $3; sev = $5; local = ""; next }
  n != "" && local == "" && /^\*\*Local:\*\*/ {
    linha = $0
    sub(/^\*\*Local:\*\*[[:space:]]*/, "", linha)
    gsub(/`/, "", linha)
    local = linha
  }
  END { flush() }
' "$REPORT")"

while IFS="$TAB" read -r num sev local; do
  [ -n "$num" ] || continue
  # O Local vem como arquivo:linha; o glob casa com o arquivo.
  arquivo="$(sed -E 's/:[0-9]+([-,][0-9]+)?[[:space:]]*$//' <<< "$local")"
  protegido=""
  while IFS= read -r glob; do
    [ -n "$glob" ] || continue
    # O */ cobre o Local escrito a partir da raiz de um monorepo.
    case "$arquivo" in
      $glob | */$glob) protegido="protegido"; break ;;
    esac
  done <<< "$PROTECTED_GLOBS"
  printf '%s\t%s\t%s\t%s\n' "$num" "$sev" "$local" "$protegido"
done <<< "$BASE"
