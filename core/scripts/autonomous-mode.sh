#!/usr/bin/env bash
# autonomous-mode.sh
#
# Imprime AUTONOMOUS=true ou AUTONOMOUS=false — usar com `eval "$(autonomous-mode.sh)"`.
# O padrão do projeto fica aqui; a variável DEV_LOOPER_AUTONOMOUS, quando definida,
# vale por cima dele só para a execução em que foi definida (é assim que um
# orquestrador liga o modo sem mudar o fluxo interativo de quem usa o projeto).
set -euo pipefail

# Padrão do projeto. Desligado: os comandos param nos checkpoints de sempre.
AUTONOMOUS=false

if [ "$AUTONOMOUS" != true ] && [ "$AUTONOMOUS" != false ]; then
  echo "AUTONOMOUS='$AUTONOMOUS' inválido em .github/scripts/autonomous-mode.sh — use true ou false" >&2
  exit 1
fi

case "${DEV_LOOPER_AUTONOMOUS:-}" in
  "") ;;
  1|true) AUTONOMOUS=true ;;
  0|false) AUTONOMOUS=false ;;
  *)
    # Valor estranho é erro, não "desligado": cair no modo errado em silêncio
    # é pior do que parar.
    echo "DEV_LOOPER_AUTONOMOUS='$DEV_LOOPER_AUTONOMOUS' inválido — use 1/true ou 0/false" >&2
    exit 1
    ;;
esac

echo "AUTONOMOUS=$AUTONOMOUS"
