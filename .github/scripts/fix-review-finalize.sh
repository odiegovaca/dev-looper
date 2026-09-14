#!/usr/bin/env bash
# fix-review-finalize.sh <relatório.md> [--applied <números>] [--dismissed "#N: motivo"]...
#
# Fecha uma rodada de /fix-review: registra no relatório o que foi aplicado e o
# que foi dispensado, deriva o status pós-fix e imprime a confirmação pronta
# para o chat — usar a saída sem alterações.
#
# O status não é argumento. Ele sai do cruzamento entre a severidade de cada
# bloco "#### Problema" e os números acumulados no relatório: status declarado
# pelo agente é o mesmo estado escrito em dois lugares, e é o lugar derivável
# que sai de sincronia.
#
# Os números acumulam entre rodadas — corrigir os critical numa chamada e os
# high na seguinte não apaga o registro da primeira.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAB="$(printf '\t')"

usage() {
  echo 'Uso: fix-review-finalize.sh <relatório.md> [--applied "#1, #3"] [--dismissed "#4: motivo"]...' >&2
  exit 1
}

REPORT="${1:-}"
[ -n "$REPORT" ] || usage
if [ ! -f "$REPORT" ]; then
  echo "Relatório não encontrado: $REPORT — o caminho sai do .github/scripts/latest-review.sh (passo 1); rode /review se a feature ainda não tem relatório" >&2
  exit 1
fi
shift

APPLIED_RAW=""
DISMISSED_RAW=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --applied)
      [ "$#" -ge 2 ] || usage
      APPLIED_RAW="$APPLIED_RAW $2"
      shift 2
      ;;
    --dismissed)
      [ "$#" -ge 2 ] || usage
      DISMISSED_RAW="$DISMISSED_RAW$2
"
      shift 2
      ;;
    *)
      echo "Argumento desconhecido: $1" >&2
      usage
      ;;
  esac
done

# Número, severidade, Local e flag de protegido — um por problema. O formato do
# bloco é interpretado só lá, e a guarda de consistência do relatório vem junto.
PROBLEMS="$("$SCRIPT_DIR/review-problems.sh" "$REPORT")"
if [ -z "$PROBLEMS" ]; then
  echo "Nenhum bloco '#### Problema' em $REPORT — nada a finalizar. Se o review apontou problemas, rode /review de novo: é o passo 2 dele que escreve os blocos." >&2
  exit 1
fi

severity_of() {
  awk -F"$TAB" -v n="$1" '$1 == n { print $2; exit }' <<< "$PROBLEMS"
}

# Normaliza qualquer forma de lista ("#1, #3", "1 3", uma por linha) nos números
# ordenados, um por linha.
sorted() {
  tr -s ' ,\n' '\n\n\n' <<< "${1:-}" | sed 's/^#//' | grep -E '^[0-9]+$' | sort -n -u || true
}

contains() {
  case " $(tr '\n' ' ' <<< "$2") " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# "#1, #3" a partir de "1 3"; "nenhuma" se a lista estiver vazia.
fmt_numbers() {
  local out="" n
  for n in $(sorted "$1"); do
    out="${out:+$out, }#$n"
  done
  echo "${out:-nenhuma}"
}

# A seção "## Pós-fix" é sempre a última do relatório, então ler dela até o fim
# do arquivo basta para recuperar o acumulado das rodadas anteriores.
PREV_SECTION="$(awk '/^## Pós-fix$/ { found = 1 } found { print }' "$REPORT")"
PREV_APPLIED="$(grep -m1 '^\*\*Correções aplicadas:\*\*' <<< "$PREV_SECTION" || true)"
PREV_DISMISSED="$(grep -E '^- #[0-9]+ \([A-Z]+\) — ' <<< "$PREV_SECTION" || true)"

APPLIED="$(sorted "$APPLIED_RAW
$PREV_APPLIED")"

# Dispensas viram um mapa "número<TAB>motivo". A rodada atual entra primeiro e
# tem precedência: reinformar um número só atualiza o motivo.
DISMISSED_MAP=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  num="$(grep -oE '[0-9]+' <<< "$line" | head -1 || true)"
  if [ -z "$num" ]; then
    echo "Não achei o número do problema em --dismissed \"$line\" — use a forma \"#N: motivo\"." >&2
    exit 1
  fi
  motivo="$(sed -E 's/^[^0-9]*[0-9]+[[:space:]]*:?[[:space:]]*//' <<< "$line")"
  DISMISSED_MAP="$DISMISSED_MAP$num$TAB${motivo:-sem motivo informado}
"
done <<< "$DISMISSED_RAW"

# Arquivo protegido é consulta, não juízo: quem mora num deles já vem marcado
# pelo review-problems.sh. Pedir ao agente que declarasse seria pedir juízo
# para o que se lê.
PROTEGIDOS="$(awk -F"$TAB" '$4 != "" { print $1 }' <<< "$PROBLEMS" || true)"
while IFS="$TAB" read -r num sev local protegido; do
  [ -n "$num" ] && [ -n "$protegido" ] || continue
  DISMISSED_MAP="$DISMISSED_MAP$num${TAB}arquivo protegido ($local) — só /setup e /lesson podem alterá-lo
"
done <<< "$PROBLEMS"

while IFS= read -r line; do
  [ -n "$line" ] || continue
  num="$(sed -E 's/^- #([0-9]+).*/\1/' <<< "$line")"
  motivo="$(sed -E 's/^- #[0-9]+ \([A-Z]+\) — //' <<< "$line")"
  if ! awk -F"$TAB" -v n="$num" '$1 == n { found = 1 } END { exit !found }' <<< "$DISMISSED_MAP"; then
    DISMISSED_MAP="$DISMISSED_MAP$num$TAB$motivo
"
  fi
done <<< "$PREV_DISMISSED"

# Protegido vence "aplicado": se o agente diz ter corrigido um problema em
# arquivo protegido, o que houve foi uma edição que não devia existir — some da
# lista de aplicados e sai como aviso, em vez de contar como bloqueante resolvido.
VIOLACOES=""
for n in $(sorted "$PROTEGIDOS"); do
  if contains "$n" "$APPLIED"; then
    VIOLACOES="$VIOLACOES $n"
    APPLIED="$(sorted "$APPLIED" | grep -vxF "$n" || true)"
  fi
done

# Número que não existe no relatório não entra na derivação — viraria um
# "bloqueante resolvido" inventado. Sai como aviso nas pendências, sem
# interromper o resto (mesma tolerância que o passo 2 do prompt promete).
UNKNOWN=""
KNOWN_APPLIED=""
for n in $(sorted "$APPLIED"); do
  if [ -n "$(severity_of "$n")" ]; then
    KNOWN_APPLIED="$KNOWN_APPLIED $n"
  else
    UNKNOWN="$UNKNOWN $n"
  fi
done
APPLIED="$KNOWN_APPLIED"

# Um número aplicado e dispensado ao mesmo tempo é contradição; a correção
# aplicada é o fato mais forte, então ela desfaz a dispensa.
KNOWN_MAP=""
while IFS="$TAB" read -r num motivo; do
  [ -n "$num" ] || continue
  if contains "$num" "$APPLIED"; then
    continue
  elif [ -n "$(severity_of "$num")" ]; then
    KNOWN_MAP="$KNOWN_MAP$num$TAB$motivo
"
  else
    UNKNOWN="$UNKNOWN $num"
  fi
done <<< "$DISMISSED_MAP"
DISMISSED_MAP="$KNOWN_MAP"
DISMISSED="$(awk -F"$TAB" 'NF { print $1 }' <<< "$DISMISSED_MAP" || true)"

ALL_NUMS="$(awk -F"$TAB" '{ print $1 }' <<< "$PROBLEMS")"
BLOCKERS="$(awk -F"$TAB" '$2 == "CRITICAL" || $2 == "HIGH" { print $1 }' <<< "$PROBLEMS" || true)"

PENDING=""
PENDING_BLOCKERS=""
for n in $(sorted "$ALL_NUMS"); do
  if contains "$n" "$APPLIED" || contains "$n" "$DISMISSED"; then
    continue
  fi
  PENDING="$PENDING $n"
  if contains "$n" "$BLOCKERS"; then
    PENDING_BLOCKERS="$PENDING_BLOCKERS $n"
  fi
done

APPLIED_BLOCKERS=""
for n in $(sorted "$APPLIED"); do
  if contains "$n" "$BLOCKERS"; then
    APPLIED_BLOCKERS="$APPLIED_BLOCKERS $n"
  fi
done

# Um bloqueante corrigido torna o relatório obsoleto como retrato do código, e
# isso vale até o próximo /review — por isso "revisar" olha o acumulado, não só
# esta rodada: senão corrigir um medium depois de um high apagaria a reanálise.
if [ -n "$PENDING_BLOCKERS" ]; then
  STATUS="bloqueado"
elif [ -n "$APPLIED_BLOCKERS" ]; then
  STATUS="revisar"
else
  STATUS="liberado"
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

{
  # Reescreve o relatório sem a seção anterior e sem as linhas em branco do fim,
  # para a seção nova não empilhar espaços a cada rodada.
  awk '/^## Pós-fix$/ { exit } { print }' "$REPORT" \
    | awk '{ l[NR] = $0 } END { while (NR > 0 && l[NR] == "") NR--; for (i = 1; i <= NR; i++) print l[i] }'
  echo
  echo "## Pós-fix"
  echo
  echo "**Correções aplicadas:** $(fmt_numbers "$APPLIED")"
  echo "**Status pós-fix:** $STATUS"
  if [ -n "$DISMISSED" ]; then
    echo
    echo "**Dispensadas:**"
    echo
    while IFS="$TAB" read -r num motivo; do
      [ -n "$num" ] || continue
      echo "- #$num ($(severity_of "$num")) — $motivo"
    done < <(awk -F"$TAB" 'NF' <<< "$DISMISSED_MAP" | sort -n)
  fi
} > "$TMP"
mv "$TMP" "$REPORT"
trap - EXIT

N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"

PENDENCIAS=""
for n in $(sorted "$VIOLACOES"); do
  PENDENCIAS="$PENDENCIAS   - #$n informado como aplicado, mas está em arquivo protegido — conferir se o arquivo foi editado indevidamente
"
done
for n in $(sorted "$UNKNOWN"); do
  PENDENCIAS="$PENDENCIAS   - #$n não existe no relatório — ignorado
"
done
while IFS="$TAB" read -r num motivo; do
  [ -n "$num" ] || continue
  PENDENCIAS="$PENDENCIAS   - #$num ($(severity_of "$num")) dispensado — $motivo
"
done < <(awk -F"$TAB" 'NF' <<< "$DISMISSED_MAP" | sort -n)
for n in $(sorted "$PENDING"); do
  PENDENCIAS="$PENDENCIAS   - #$n ($(severity_of "$n")) não corrigido nesta rodada
"
done
if [ -z "$PENDENCIAS" ]; then
  PENDENCIAS="   - nenhuma
"
fi

echo "✅ Correções aplicadas: $(fmt_numbers "$APPLIED")"
echo "   Status pós-fix: $STATUS"
echo
echo "   Pendências:"
printf '%s' "$PENDENCIAS"
echo
echo "   Checkpoint sugerido: git commit -m \"fix: aplica correções do review${N:+ #$N}\""
echo
echo "   Próximo passo:"
case "$STATUS" in
  bloqueado)
    # Números crus porque é o comando que o usuário vai digitar (o seletor
    # aceita as duas formas — o fix-review-select.sh tira o "#").
    echo "   - /fix-review $(sorted "$PENDING_BLOCKERS" | tr '\n' ' ' | sed 's/ $//') — bloqueantes ainda pendentes."
    ;;
  revisar)
    echo "   - /review — bloqueante corrigido, revalidar antes de seguir para /rc."
    ;;
  liberado)
    echo "   - /rc — nenhum bloqueante pendente."
    ;;
esac
