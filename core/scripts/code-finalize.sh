#!/usr/bin/env bash
# code-finalize.sh "<descrição>"
#
# Fecha o /dl-code — usar a saída sem alterações. No modo interativo, imprime os
# próximos passos com o checkpoint de commit já com a mensagem. No autônomo, o
# checkpoint sai (o diff final, no PR, mostra a mesma coisa) e o commit é feito aqui.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo 'Uso: code-finalize.sh "<descrição curta da funcionalidade>"' >&2
  exit 1
fi
MESSAGE="feat: $1"

MODE_VARS="$("$SCRIPT_DIR/autonomous-mode.sh")" || exit 1
eval "$MODE_VARS"

if [ "$AUTONOMOUS" = true ]; then
  git add .
  "$SCRIPT_DIR/protect-stage.sh"
  # Nada no stage depois do protect-stage é sinal de que algo deu errado
  # (ou só arquivo protegido mudou): parar, não commitar vazio.
  if git diff --cached --quiet; then
    echo "Nada para commitar depois do protect-stage.sh — confira se a implementação gerou mudanças fora dos Arquivos Protegidos" >&2
    exit 1
  fi
  git commit -q -m "$MESSAGE"
  echo "✅ Implementação concluída: $(git log -1 --format='%h %s')"
  exit 0
fi

cat <<EOF
✅ Implementação concluída. Próximos passos:

1. Revise as Changes da branch (git diff ou painel Source Control)
2. Se aprovado: git commit -m "$MESSAGE"  ← checkpoint antes do review
3. /dl-test    → completar cobertura até a meta do projeto (casos de borda e gaps)
4. /dl-review  → revisão de qualidade antes do PR
5. /dl-rc      → criar PR
EOF
