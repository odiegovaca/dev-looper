#!/usr/bin/env bash
# autonomous-mode.sh
#
# Imprime AUTONOMOUS=true|false e, só com o modo ligado, AUTONOMOUS_RULES='...'
# com as regras que valem em toda fase. Os prompts seguem as regras; os scripts
# usam `eval "$(autonomous-mode.sh)"` e ignoram AUTONOMOUS_RULES.
#
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

if [ "$AUTONOMOUS" = false ]; then
  exit 0
fi

# Regras comuns a todas as fases. O que muda em cada uma (o commit no lugar do
# checkpoint, por exemplo) fica no script de fechamento dela.
# O texto vai entre aspas simples para o eval: nada de aspa simples dentro dele.
cat <<'EOF'
AUTONOMOUS_RULES='Modo autônomo: não há ninguém no chat.
- Onde o prompt mandar perguntar ou confirmar algo com o usuário, ou um passo obrigatório falhar sem conserto (a validação, por exemplo), pare: termine sem commit e comece a resposta com `⛔ Parado: <motivo>`. Não decida no lugar do usuário.
- Os checkpoints de revisão humana saem. O script de fechamento da fase diz o que fazer no lugar deles; use a saída dele sem alterações e não sugira próximos passos — quem chama a próxima fase é o orquestrador.'
EOF
