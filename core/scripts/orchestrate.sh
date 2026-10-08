#!/usr/bin/env bash
# orchestrate.sh <spec> [--desde code|test|review|rc]
#
# Leva uma issue da spec aprovada até o PR sem ninguém no meio. Cada fase roda
# numa sessão nova do agente (run-phase.sh), no modo autônomo, e entre uma e
# outra a decisão é regra sobre o que ficou em disco: o commit, o relatório do
# review, o status pós-fix. O que a regra não decide para a esteira e chama o
# usuário — o gate de entrada é a spec, o de saída é o PR.
#
# Ordem: code → test → review → (fix → review)… → rc. Depois de cada review ou
# fix, a próxima fase sai do next-step.sh, que é o dono da tabela e do teto de
# rodadas. --desde retoma de uma fase depois de uma parada, já na branch da issue.
#
# O log fica em <git-dir>/dev-looper/runs/: fora da árvore de trabalho, para o
# `git add .` dos scripts de fechamento nunca levá-lo para um commit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USO="Uso: orchestrate.sh <spec> [--desde code|test|review|rc]"

# Fases rodadas antes de desistir. O caminho mais longo que as regras permitem é
# code, test, três reviews, dois fixes (o teto do next-step.sh) e rc: oito.
MAX_FASES=10

SPEC=""
DESDE=code
while [ $# -gt 0 ]; do
  case "$1" in
    --desde)
      [ $# -ge 2 ] || { echo "$USO" >&2; exit 1; }
      DESDE="$2"
      shift
      ;;
    --desde=*) DESDE="${1#--desde=}" ;;
    -*) echo "Argumento desconhecido: $1 — $USO" >&2; exit 1 ;;
    *) SPEC="$1" ;;
  esac
  shift
done

case "$DESDE" in
  code|test|review|rc) ;;
  *) echo "--desde '$DESDE' inválido — use code, test, review ou rc" >&2; exit 1 ;;
esac
[ -n "$SPEC" ] || { echo "$USO" >&2; exit 1; }
[ -f "$SPEC" ] || { echo "Spec não encontrada: $SPEC" >&2; exit 1; }

# --- Gate de entrada: a esteira só parte de spec aprovada e com issue ----------

# Mesmos campos que o spec-status.sh lê.
STATUS="$(grep -m1 '^\*\*Status\*\*:' "$SPEC" | sed -E 's/^\*\*Status\*\*:[[:space:]]*`([^`]+)`.*/\1/' || true)"
ISSUE="$(grep -m1 -E '^\*\*Issue\*\*: \[?#[0-9]+' "$SPEC" | sed -E 's/^\*\*Issue\*\*: \[?#([0-9]+).*/\1/' || true)"
PENDENTES="$(awk '
  /^## Questões em Aberto/ { found = 1; next }
  found && /^## / { exit }
  found && /^- / { n++ }
  END { print n + 0 }
' "$SPEC")"

case "$STATUS" in
  Aprovada|Aprovado|"Issue criada") ;;
  *) echo "Spec com Status '${STATUS:-ausente}' — a esteira só parte de spec aprovada: aprovar é o gate de entrada, e é seu." >&2; exit 1 ;;
esac
if [ "$PENDENTES" -gt 0 ]; then
  echo "A spec tem $PENDENTES questão(ões) em aberto — sem ninguém no chat, o agente adivinharia a resposta. Responda antes." >&2
  exit 1
fi
if [ -z "$ISSUE" ]; then
  echo "A spec não tem issue vinculada — rode /dl-issue: o número dela nomeia a branch, o review e o PR." >&2
  exit 1
fi

eval "$("$SCRIPT_DIR/release-branches.sh")"

if [ -n "$(git status --porcelain)" ]; then
  echo "Há mudanças sem commit — a esteira começa de árvore limpa, para cada commit dela ser só dela." >&2
  git status --short >&2
  exit 1
fi

# --- Branch da issue ---------------------------------------------------------

ATUAL="$(git branch --show-current)"
N_ATUAL="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"

if [ "$N_ATUAL" = "$ISSUE" ]; then
  # Já na branch da issue (uma retomada, ou a branch criada à mão): segue nela.
  BRANCH="$ATUAL"
elif [ "$DESDE" != code ]; then
  echo "--desde $DESDE retoma uma esteira: rode de dentro da branch da issue #$ISSUE (está em '${ATUAL:-DETACHED}')." >&2
  exit 1
elif [ "$ATUAL" != "$INTEGRATION_BRANCH" ]; then
  echo "A esteira cria a branch da issue a partir de $INTEGRATION_BRANCH — troque para ela (está em '${ATUAL:-DETACHED}')." >&2
  exit 1
else
  # A base do PR é o origin: partir de uma integração local defasada, ou com
  # commits que não subiram, poria no PR o que não é da issue.
  git fetch origin "$INTEGRATION_BRANCH" --quiet
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$INTEGRATION_BRANCH")" ]; then
    echo "$INTEGRATION_BRANCH local difere de origin/$INTEGRATION_BRANCH — sincronize (git pull / git push) antes de abrir a esteira." >&2
    exit 1
  fi
  # O nome sai do identificador da spec: spec-AAAA-MM-DD-<id>.md.
  ID="$(basename "$SPEC" .md | sed -E 's/^spec-[0-9]{4}-[0-9]{2}-[0-9]{2}-//; s/^spec-//')"
  BRANCH="feature/${ISSUE}-${ID}"
  if git rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null; then
    echo "A branch $BRANCH já existe — para continuar o que está nela, troque para ela e use --desde; para recomeçar, apague-a antes." >&2
    exit 1
  fi
  git checkout -q -b "$BRANCH"
fi

# --- Log -----------------------------------------------------------------------

GIT_COMUM="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
RUN_DIR="$GIT_COMUM/dev-looper/runs/${ISSUE}-$("$SCRIPT_DIR/hoje.sh" %Y-%m-%d-%H%M%S)"
mkdir -p "$RUN_DIR"
LOG="$RUN_DIR/run.md"

hora() { "$SCRIPT_DIR/hoje.sh" %H:%M; }

# duracao <segundos> — "1h02m", "12m04s" ou "40s".
duracao() {
  local s="$1"
  if [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  elif [ "$s" -ge 60 ]; then printf '%dm%02ds' $((s / 60)) $((s % 60))
  else printf '%ds' "$s"
  fi
}

# Vai para o terminal e para o log, o mesmo texto nos dois.
log() { printf '%s\n' "$*" | tee -a "$LOG"; }

# A saída do orquestrador também no descritor 4: dentro do $(...) que captura a
# resposta da fase, o stdout é a captura, e as ações do agente saem por aqui.
exec 4>&1

INICIO="$(date +%s)"
FASE_ATUAL=""

# parar <motivo> — fecha o log com o motivo e o comando de retomada.
parar() {
  local retomar="$FASE_ATUAL"
  # Um fix interrompido se retoma pelo review: o que o usuário corrigir à mão
  # precisa de commit e de um review que o leia.
  [ "$retomar" != fix ] || retomar=review
  log ""
  log "⛔ Esteira parada: $1"
  log ""
  log "Tempo até a parada: $(duracao $(( $(date +%s) - INICIO )))"
  if [ -n "$retomar" ]; then
    log "Para retomar, depois de resolver: $0 $SPEC --desde $retomar"
  fi
  log "Respostas de cada fase: $RUN_DIR"
  # Fase interrompida no meio deixa só o stderr, com as ações até ali.
  local err
  for err in "$RUN_DIR"/*.err; do
    [ ! -f "$err" ] || mv "$err" "${err%.err}"
  done
  exit 1
}
trap 'parar "interrompida pelo usuário"' INT

{
  echo "# Esteira da issue #$ISSUE"
  echo
  echo "- **Spec:** \`$SPEC\`"
  echo "- **Branch:** \`$BRANCH\`, PR para \`$INTEGRATION_BRANCH\`"
  echo "- **Início:** $("$SCRIPT_DIR/hoje.sh" '%Y-%m-%d %H:%M'), desde \`$DESDE\`"
  echo
  echo "## Fases"
  echo
} > "$LOG"
cat "$LOG"

# --- Fases ---------------------------------------------------------------------

N_FASES=0
RESPOSTA=""

# fase <nome> [argumentos...] — roda a fase e para a esteira se a sessão falhou,
# se a fase parou sozinha ou se ela saiu da branch. As conferências próprias de
# cada fase ficam no laço principal.
fase() {
  local nome="$1" inicio arquivo resumo
  shift
  FASE_ATUAL="$nome"
  N_FASES=$((N_FASES + 1))
  [ "$N_FASES" -le "$MAX_FASES" ] || parar "$MAX_FASES fases sem chegar ao PR — laço que as regras não pegaram."

  arquivo="$RUN_DIR/$(printf '%02d' "$N_FASES")-$nome.md"
  inicio="$(date +%s)"
  printf '▶ %s /dl-%s%s\n' "$(hora)" "$nome" "${*:+ $*}"

  # As ações do agente vão para o terminal pelo descritor 3 e, com o resto do
  # stderr, para o arquivo da fase.
  if ! RESPOSTA="$("$SCRIPT_DIR/run-phase.sh" "$nome" "$@" 3>&4 2> "$arquivo.err")"; then
    { echo "## stderr"; echo; cat "$arquivo.err"; } > "$arquivo"
    rm -f "$arquivo.err"
    log "- $(hora) \`/dl-$nome${*:+ $*}\` — $(duracao $(( $(date +%s) - inicio ))) — a sessão não terminou"
    parar "a sessão do /dl-$nome falhou: $(grep -v -e '^ℹ️' -e '^$' -e '^## stderr' "$arquivo" | tail -1)"
  fi
  { printf '%s\n' "$RESPOSTA"; echo; echo "---"; echo; cat "$arquivo.err"; } > "$arquivo"

  # A primeira linha com conteúdo, fora título, resume a fase: os scripts de
  # fechamento imprimem o resultado nela, e a regra do modo autônomo põe o ⛔ ali.
  resumo="$(grep -v '^#' <<< "$RESPOSTA" | grep -m1 . | cut -c1-200 || true)"
  log "- $(hora) \`/dl-$nome${*:+ $*}\` — $(duracao $(( $(date +%s) - inicio ))) — ${resumo:-sem resposta}"
  grep '^⚠️ negado:' "$arquivo.err" | sed 's/^/  /' | tee -a "$LOG" || true
  rm -f "$arquivo.err"

  local parado
  parado="$(grep -m1 '⛔ Parado' <<< "$RESPOSTA" || true)"
  [ -z "$parado" ] || parar "o /dl-$nome parou: ${parado#*⛔ Parado: }"

  [ "$(git branch --show-current)" = "$BRANCH" ] || parar "o /dl-$nome saiu da branch $BRANCH (está em '$(git branch --show-current)')."
}

arvore_limpa() {
  [ -z "$(git status --porcelain)" ] || parar "o /dl-$FASE_ATUAL terminou com mudanças sem commit: $(git status --porcelain | head -3 | tr '\n' ' ')"
}

# Lê o último relatório e devolve, em PROXIMA e ARGS, o que o next-step.sh manda.
decidir() {
  local key value report="" veredito="" status="" bloqueantes="" stats="" next sel
  while IFS='=' read -r key value; do
    case "$key" in
      REPORT)         report="$value" ;;
      VEREDITO)       veredito="$value" ;;
      STATUS_POS_FIX) status="$value" ;;
      BLOQUEANTES)    bloqueantes="$value" ;;
      STATS)          stats="$value" ;;
    esac
  done < <("$SCRIPT_DIR/review-state.sh")
  [ -n "$report" ] || parar "nenhum relatório de review da issue #$ISSUE para decidir o passo seguinte."

  next="$("$SCRIPT_DIR/next-step.sh" "$veredito" "$status" "$bloqueantes" "$report")"
  log "  ↳ $(basename "$report"): ${stats:-sem estatísticas} · ${veredito:-sem veredito}${status:+ · pós-fix: $status}"
  log "  ↳ $next"
  case "$next" in
    "/dl-fix "*)
      sel="${next#/dl-fix }"
      PROXIMA=fix
      ARGS="${sel%% — *}"
      ;;
    /dl-review*) PROXIMA=review ;;
    /dl-rc*)     PROXIMA=rc ;;
    "⛔"*)       parar "${next#⛔ }" ;;
    *)           parar "próximo passo não reconhecido: $next" ;;
  esac
}

PROXIMA="$DESDE"
ARGS=""
ANTERIOR=""
while true; do
  # Fase que se repete sem outra no meio é a anterior que não fez o que devia:
  # fix depois de fix deixou bloqueante sem aplicar nem dispensar, e review
  # depois de review não teve o que revisar.
  if [ "$PROXIMA" = "$ANTERIOR" ]; then
    parar "/dl-$PROXIMA duas vezes seguidas — o /dl-$ANTERIOR anterior não mudou o estado do ciclo (veja a resposta dele)."
  fi
  ANTERIOR="$PROXIMA"

  case "$PROXIMA" in
    code)
      HEAD_ANTES="$(git rev-parse HEAD)"
      fase code "$SPEC"
      [ "$(git rev-parse HEAD)" != "$HEAD_ANTES" ] || parar "o /dl-code terminou sem commit."
      arvore_limpa
      PROXIMA=test
      ;;
    test)
      fase test
      arvore_limpa
      PROXIMA=review
      ;;
    review)
      REPORT_ANTES="$("$SCRIPT_DIR/latest-review.sh" 2>/dev/null || true)"
      fase review
      REPORT_DEPOIS="$("$SCRIPT_DIR/latest-review.sh" 2>/dev/null || true)"
      if [ -z "$REPORT_DEPOIS" ] || [ "$REPORT_DEPOIS" = "$REPORT_ANTES" ]; then
        parar "o /dl-review terminou sem relatório novo."
      fi
      decidir
      ;;
    fix)
      # Sem aspas de propósito: o seletor são palavras ("critical high", "3 7").
      # shellcheck disable=SC2086
      fase fix $ARGS
      arvore_limpa
      decidir
      ;;
    rc)
      fase rc
      GH_REPO="$("$SCRIPT_DIR/gh-repo.sh")"
      PR_URL="$(gh pr view "$BRANCH" --repo "$GH_REPO" --json url,state --jq 'select(.state == "OPEN") | .url' 2>/dev/null || true)"
      [ -n "$PR_URL" ] || parar "o /dl-rc terminou sem PR aberto para $BRANCH."
      break
      ;;
  esac
done

trap - INT
log ""
log "✅ PR aberto: $PR_URL"
log ""
log "Tempo total: $(duracao $(( $(date +%s) - INICIO ))) em $N_FASES fases"
log "Respostas de cada fase: $RUN_DIR"
