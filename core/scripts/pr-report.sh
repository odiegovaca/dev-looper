#!/usr/bin/env bash
# pr-report.sh
#
# Imprime, em Markdown, as seções do corpo do PR que saem do ciclo da feature:
# perguntas para o usuário (dispensas do agente), achados fora do escopo, o que
# ficou sem corrigir, lacuna de cobertura e as rodadas de review. É o material
# do gate de saída: quem aprova o PR lê isto em vez do diff linha por linha.
#
# Os relatórios em docs/reviews/ podem não estar versionados, então o conteúdo
# vai inteiro aqui, não em link. A spec não: ela é o corpo da issue, que o PR já
# fecha. Seção sem conteúdo não sai; sem nada, a saída é vazia.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAB="$(printf '\t')"

N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"
[ -n "$N" ] || exit 0

REPORTS="$(ls "docs/reviews/review-${N}-"*.md 2>/dev/null | sort -V || true)"

# Bloco de um achado, do cabeçalho até o próximo título, sem as linhas em branco do fim.
block() {
  awk -v h="$2" '
    $0 ~ h { found = 1; print; next }
    found && /^#{1,4} / { exit }
    found { print }
  ' "$1" | awk '{ l[NR] = $0 } END { while (NR > 0 && l[NR] == "") NR--; for (i = 1; i <= NR; i++) print l[i] }'
}

# O bloco num <details> fechado: as linhas em branco em volta deixam o GitHub
# renderizar o Markdown dele.
details() {
  echo "<details><summary>$1</summary>"
  echo
  printf '%s\n' "$2"
  echo
  echo "</details>"
}

PERGUNTAS=""
FORA=""
FICOU=""
RODADAS=""

while IFS= read -r REPORT; do
  [ -n "$REPORT" ] || continue
  SEQ="$(sed -E "s#.*review-${N}-([0-9]+)\.md#\1#" <<< "$REPORT")"
  NOME="Review $SEQ"

  ESCOPO="$(grep -m1 '^\*\*Escopo:\*\*' "$REPORT" | sed -E 's/^\*\*Escopo:\*\*[[:space:]]*([a-z]+).*/\1/' || true)"
  STATS="$(grep -m1 '^\*\*Estatísticas:\*\*' "$REPORT" | sed -E 's/^\*\*Estatísticas:\*\*[[:space:]]*//' || true)"
  VEREDITO="$(grep -m1 '^\*\*Veredito:\*\*' "$REPORT" | sed -E 's/^\*\*Veredito:\*\*[[:space:]]*//' || true)"
  STATUS="$(grep -m1 '^\*\*Status pós-fix:\*\*' "$REPORT" | sed -E 's/^\*\*Status pós-fix:\*\*[[:space:]]*//' || true)"
  RODADAS="$RODADAS- $NOME${ESCOPO:+ ($ESCOPO)}: ${STATS:-sem estatísticas} — ${VEREDITO:-sem veredito}${STATUS:+; pós-fix: $STATUS}
"

  POS_FIX="$(awk '/^## Pós-fix$/ { found = 1 } found { print }' "$REPORT")"
  APLICADAS=" $(grep -m1 '^\*\*Correções aplicadas:\*\*' <<< "$POS_FIX" | grep -oE '[0-9]+' | tr '\n' ' ' || true)"

  PROBLEMS="$("$SCRIPT_DIR/review-problems.sh" "$REPORT")"
  while IFS="$TAB" read -r num sev local _protegido; do
    [ -n "$num" ] || continue
    case "$APLICADAS " in *" $num "*) continue ;; esac
    BLOCO="$(block "$REPORT" "^#### Problema $num — ")"
    ROTULO="$NOME, #$num ($sev)${local:+ \`$local\`}"
    motivo="$(grep -m1 -E "^- #$num \([A-Z]+\) — " <<< "$POS_FIX" | sed -E 's/^- #[0-9]+ \([A-Z]+\) — //' || true)"
    case "$motivo" in
      "agente — exige decisão: "* | "agente — não é problema: "*)
        caso="$(sed -E 's/^agente — ([^:]+): .*/\1/' <<< "$motivo")"
        texto="$(sed -E 's/^agente — [^:]+: //' <<< "$motivo")"
        if [ "$caso" = "exige decisão" ]; then rotulo_texto="Proposta"; else rotulo_texto="Por quê"; fi
        PERGUNTAS="$PERGUNTAS### $ROTULO — $caso

**$rotulo_texto:** $texto

$(details "O problema" "$BLOCO")

"
        ;;
      *)
        explicacao="$(grep -m1 '^\*\*Explicação:\*\*' <<< "$BLOCO" | sed -E 's/^\*\*Explicação:\*\*[[:space:]]*//' || true)"
        FICOU="$FICOU- $ROTULO${explicacao:+: $explicacao} — ${motivo:+dispensado: }${motivo:-não corrigido}
"
        ;;
    esac
  done <<< "$PROBLEMS"

  while IFS="$TAB" read -r num sev; do
    [ -n "$num" ] || continue
    BLOCO="$(block "$REPORT" "^#### Fora do escopo $num — ")"
    local_fora="$(grep -m1 '^\*\*Local:\*\*' <<< "$BLOCO" | sed -E 's/^\*\*Local:\*\*[[:space:]]*//' || true)"
    FORA="$FORA### $NOME, fora do escopo #$num ($sev)${local_fora:+ $local_fora}

$(details "O achado" "$BLOCO")

"
  done < <(sed -nE "s/^#### Fora do escopo ([0-9]+) — ([A-Z]+)$/\1$TAB\2/p" "$REPORT")
done <<< "$REPORTS"

# A lacuna vem da mensagem do último commit do /dl-test (test-finalize.sh).
COBERTURA=""
if BRANCHES="$("$SCRIPT_DIR/release-branches.sh" 2>/dev/null)"; then
  eval "$BRANCHES"
  ULTIMO_TESTE="$(git log --format=%s "origin/$INTEGRATION_BRANCH..HEAD" 2>/dev/null | grep -m1 '^test: ' || true)"
  if [[ "$ULTIMO_TESTE" =~ \(([0-9.]+)%\ de\ ([0-9.]+)%\) ]]; then
    COBERTURA="Meta não atingida: ${BASH_REMATCH[1]}% (meta ${BASH_REMATCH[2]}%)."
  fi
fi

if [ -n "$PERGUNTAS" ]; then
  echo "## Perguntas para você"
  echo
  echo "O agente deixou estes achados sem corrigir e espera a sua decisão."
  echo
  printf '%s' "$PERGUNTAS"
fi
if [ -n "$FORA" ]; then
  echo "## Fora do escopo"
  echo
  echo "Achados graves em código que o review incremental não cobria. Não contaram para o veredito."
  echo
  printf '%s' "$FORA"
fi
if [ -n "$FICOU" ]; then
  echo "## O que ficou sem corrigir"
  echo
  printf '%s' "$FICOU"
  echo
fi
if [ -n "$COBERTURA" ]; then
  echo "## Cobertura"
  echo
  echo "$COBERTURA"
  echo
fi
if [ -n "$RODADAS" ]; then
  echo "## Rodadas de review"
  echo
  printf '%s' "$RODADAS"
fi
