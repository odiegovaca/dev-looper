#!/usr/bin/env bash
# test-finalize.sh [meta]
#
# Fecha o /dl-test — usar a saída sem alterações. Compara a cobertura do relatório
# (coverage.sh) com a meta: a passada como argumento ou, sem ela, a do projeto.
# No modo interativo, imprime os próximos passos com o checkpoint de commit quando
# a meta saiu. No autônomo, o checkpoint sai e o commit é feito aqui.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -gt 1 ]; then
  echo 'Uso: test-finalize.sh [meta em %]' >&2
  exit 1
fi

# Aceita "80", "80%" e "82,5" — é o que o usuário digita no argumento do /dl-test.
TARGET="${1:-}"
TARGET="${TARGET%\%}"
TARGET="${TARGET/,/.}"
if [ -z "$TARGET" ]; then
  TARGET="$("$SCRIPT_DIR/coverage.sh" --target)"
fi
if ! [[ "$TARGET" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Meta '$TARGET' inválida — use só o número, em %" >&2
  exit 1
fi

COVERAGE="$("$SCRIPT_DIR/coverage.sh")"

MODE_VARS="$("$SCRIPT_DIR/autonomous-mode.sh")" || exit 1
eval "$MODE_VARS"

if awk -v c="$COVERAGE" -v t="$TARGET" 'BEGIN { exit !(c + 0 >= t + 0) }'; then
  MET=true
  RESULT="✅ Meta atingida: $COVERAGE% (meta $TARGET%)"
  MESSAGE="test: completa cobertura"
else
  MET=false
  RESULT="⚠️ Meta não atingida: $COVERAGE% (meta $TARGET%)"
  MESSAGE="test: amplia cobertura ($COVERAGE% de $TARGET%)"
fi

if [ "$AUTONOMOUS" = true ]; then
  # Meta não atingida também vira commit: os testes escritos passaram na
  # validação, e a lacuna segue na mensagem até o PR, que é onde alguém decide.
  git add .
  "$SCRIPT_DIR/protect-stage.sh"
  # Stage vazio aqui não é erro: a meta pode já estar atingida antes do /dl-test.
  if git diff --cached --quiet; then
    echo "$RESULT — nada para commitar"
    exit 0
  fi
  git commit -q -m "$MESSAGE"
  echo "$RESULT — commit $(git log -1 --format='%h %s')"
  exit 0
fi

if [ "$MET" = true ]; then
  cat <<EOF
$RESULT. Próximos passos:

1. git commit -m "$MESSAGE"  ← checkpoint antes do review
2. /dl-review  → revisão de qualidade antes do PR
EOF
else
  echo "$RESULT. As lacunas acima ficam para cobertura manual."
fi
