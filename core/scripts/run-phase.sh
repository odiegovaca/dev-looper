#!/usr/bin/env bash
# run-phase.sh <code|test|review|fix|rc> [argumentos...]
#
# Roda uma fase do fluxo numa sessão nova do agente, no modo autônomo, e imprime
# a resposta final dela. É o único ponto do orquestrador que depende do agente:
# o resto lê o que ficou em disco. Cada chamada é um contexto novo — autor, juiz
# e executor não dividem conversa.
#
# Sai com erro só quando a sessão não chegou ao fim. A fase que parou por conta
# própria (`⛔ Parado`) sai com 0: quem lê a resposta é o orquestrador. Em stderr,
# uma linha com a sessão e o custo, e as ferramentas negadas, se houver.
set -euo pipefail

AGENT='{{AGENT}}'

FASE="${1:-}"
case "$FASE" in
  code|test|review|fix|rc) ;;
  *) echo "Uso: run-phase.sh <code|test|review|fix|rc> [argumentos...]" >&2; exit 1 ;;
esac
shift
PROMPT="/dl-$FASE${*:+ $*}"

case "$AGENT" in
  claude)
    for cmd in claude jq; do
      command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd não encontrado — o adaptador do Claude precisa dele no PATH" >&2; exit 1; }
    done

    # Sem ninguém para confirmar, ferramenta negada faz a fase desistir no meio.
    # Daqui saem só as do fluxo: edição, os scripts, git e gh. O que é do projeto
    # (o teste que o agente roda solto, por exemplo) vai nas permissões do
    # .claude/settings.json dele, que valem por cima destas.
    # stdin fechado: sem ele, o `claude -p` espera entrada quando roda sem terminal.
    CODIGO=0
    SAIDA="$(DEV_LOOPER_AUTONOMOUS=1 claude -p "$PROMPT" \
      --output-format json \
      --permission-mode acceptEdits \
      --allowedTools 'Bash({{SCRIPTS_DIR}}/*)' 'Bash(git *)' 'Bash(gh *)' \
      < /dev/null)" || CODIGO=$?

    if ! jq -e . >/dev/null 2>&1 <<< "$SAIDA"; then
      [ -z "$SAIDA" ] || printf '%s\n' "$SAIDA" | tail -5 >&2
      echo "claude -p saiu com código $CODIGO sem devolver o resultado da sessão" >&2
      exit 1
    fi

    jq -r '"ℹ️ sessão \(.session_id) · \(.num_turns) turnos · US$ \(.total_cost_usd * 100 | round / 100)"' <<< "$SAIDA" >&2
    jq -r '.permission_denials[]? | "⚠️ negado: \(.tool_name) \(.tool_input | tostring | .[0:200])"' <<< "$SAIDA" >&2

    if [ "$(jq -r '.is_error' <<< "$SAIDA")" = true ]; then
      echo "A sessão terminou com erro ($(jq -r '.subtype' <<< "$SAIDA")): $(jq -r '.result // ""' <<< "$SAIDA" | head -3)" >&2
      exit 1
    fi

    jq -r '.result' <<< "$SAIDA"
    ;;
  *)
    echo "O orquestrador ainda não roda com o agente '$AGENT' — só o adaptador do Claude existe (install.sh --agent claude)." >&2
    exit 1
    ;;
esac
