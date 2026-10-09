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
# uma linha por ação do agente enquanto a fase roda, e no fim a sessão, o custo
# e as ferramentas negadas, se houver. Com o descritor 3 aberto, as ações vão
# também para ele: é por onde o orquestrador as mostra no terminal enquanto
# guarda o stderr no log.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT='{{AGENT}}'

FD3=false
if { true >&3; } 2>/dev/null; then
  FD3=true
fi

# progresso — lê uma ação por linha e imprime com a hora, sem esperar a fase acabar.
progresso() {
  local linha
  while IFS= read -r linha; do
    linha="  · $("$SCRIPT_DIR/hoje.sh" %H:%M) $linha"
    printf '%s\n' "$linha" >&2
    [ "$FD3" = false ] || printf '%s\n' "$linha" >&3
  done
}

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

    # Em diretório que o Claude Code ainda não marcou como confiável, ele ignora as
    # permissões do .claude/settings*.json do projeto só com um aviso no stderr, e
    # a fase roda com comandos do projeto negados (no Ordis, em 2026-10-08, o
    # /dl-code escreveu à mão o código gerado porque o build_runner foi negado).
    RAIZ="$(git rev-parse --show-toplevel)"
    CONFIG="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
    if ls "$RAIZ"/.claude/settings*.json >/dev/null 2>&1 && [ -f "$CONFIG" ] \
      && ! jq -e --arg p "$RAIZ" '.projects[$p].hasTrustDialogAccepted == true' "$CONFIG" >/dev/null; then
      echo "O Claude Code ainda não confia em $RAIZ e ignoraria as permissões de .claude/settings*.json — abra \`claude\` nesse diretório uma vez, aceite a pergunta de confiança e rode de novo." >&2
      exit 1
    fi

    # Sem ninguém para confirmar, ferramenta negada faz a fase desistir no meio.
    # Daqui saem só as do fluxo: edição, os scripts, git e gh. O que é do projeto
    # (o teste que o agente roda solto, por exemplo) vai nas permissões do
    # .claude/settings.json dele, que valem por cima destas.
    # stdin fechado: sem ele, o `claude -p` espera entrada quando roda sem terminal.
    # Sem tarefas em segundo plano: no -p, a sessão acaba quando o agente encerra a
    # vez, e quem rodou a validação em segundo plano para esperar o aviso de fim
    # termina a fase no meio (o /dl-test do Ordis, em 2026-10-08).
    # O stream traz um evento por mensagem: as ações saem enquanto a fase roda, e o
    # resultado da sessão é o último evento, guardado em $EVENTOS.
    EVENTOS="$(mktemp)"
    trap 'rm -f "$EVENTOS" "$EVENTOS.codigo"' EXIT
    {
      CODIGO=0
      DEV_LOOPER_AUTONOMOUS=1 CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 claude -p "$PROMPT" \
        --output-format stream-json --verbose \
        --permission-mode acceptEdits \
        --allowedTools 'Bash({{SCRIPTS_DIR}}/*)' 'Bash(git *)' 'Bash(gh *)' \
        < /dev/null || CODIGO=$?
      echo "$CODIGO" > "$EVENTOS.codigo"
    } | tee "$EVENTOS" \
      | jq --unbuffered -R -r --arg cwd "$PWD/" '
          fromjson? | select(.type == "assistant") | .message.content[]?
          | select(.type == "tool_use" and .name != "TodoWrite")
          | "\(.name) \(.input.command // .input.file_path // .input.pattern // .input.description // ""
                       | tostring | ltrimstr($cwd) | split("\n")[0] | .[0:140])"' \
      | progresso

    SAIDA="$(jq -c -R 'fromjson? | select(.type == "result")' "$EVENTOS" | tail -1)"
    if [ -z "$SAIDA" ]; then
      grep -v '^{' "$EVENTOS" | tail -5 >&2 || true
      echo "claude -p saiu com código $(cat "$EVENTOS.codigo" 2>/dev/null || echo '?') sem devolver o resultado da sessão" >&2
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
