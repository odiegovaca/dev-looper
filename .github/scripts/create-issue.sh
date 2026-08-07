#!/usr/bin/env bash
# create-issue.sh [spec-path]
#
# Cria uma issue GitHub a partir de uma spec aprovada. Título e label são
# extraídos da spec; o corpo é o conteúdo integral do arquivo — sem
# inferência do agente. Se spec-path for omitido, busca a única spec com
# Status: Aprovada em docs/issues/ (erro se houver zero ou mais de uma).
#
# Imprime ISSUE_NUMBER, ISSUE_URL e SPEC_PATH no stdout em caso de sucesso.
set -euo pipefail

SPEC_PATH="${1:-}"

# Sem argumento: descobre a spec sozinho. Varre docs/issues/spec-*.md e
# guarda em CANDIDATES só as que têm Status Aprovada/Aprovado — precisa
# sobrar exatamente uma, senão erra (zero specs prontas, ou ambíguo demais
# pra escolher sozinho).
if [[ -z "$SPEC_PATH" ]]; then
  CANDIDATES=()
  while IFS= read -r f; do
    grep -qE '^\*\*Status\*\*: `Aprovad[ao]`' "$f" && CANDIDATES+=("$f")
  done < <(ls docs/issues/spec-*.md 2>/dev/null || true)

  if [[ "${#CANDIDATES[@]}" -eq 0 ]]; then
    echo "Nenhuma spec com Status: Aprovada encontrada em docs/issues/" >&2
    exit 1
  elif [[ "${#CANDIDATES[@]}" -gt 1 ]]; then
    echo "Múltiplas specs aprovadas — rode de novo passando o caminho de uma:" >&2
    printf '%s\n' "${CANDIDATES[@]}" >&2
    exit 1
  fi
  SPEC_PATH="${CANDIDATES[0]}"
fi

[[ -f "$SPEC_PATH" ]] || { echo "Spec não encontrada: $SPEC_PATH" >&2; exit 1; }

# Lê os três campos que o resto do script precisa, direto do texto da spec:
# TITLE vem do H1 (primeira linha "# ..."), STATUS e TIPO vêm das linhas
# "**Campo**: `valor`" do cabeçalho — mesmo formato usado no template do
# /spec, então o grep+sed funciona em qualquer spec gerada por ele.
TITLE="$(grep -m1 '^# ' "$SPEC_PATH" | sed 's/^# //')"
STATUS="$(grep -m1 '^\*\*Status\*\*:' "$SPEC_PATH" | sed -E 's/^\*\*Status\*\*:[[:space:]]*`([^`]+)`.*/\1/')"
TIPO="$(grep -m1 '^\*\*Tipo\*\*:' "$SPEC_PATH" | sed -E 's/^\*\*Tipo\*\*:[[:space:]]*`([^`]+)`.*/\1/')"

# Validações: sem título não dá pra criar issue; status precisa ser
# Aprovada (aceita a variação "Aprovado" pra não travar em typo de gênero);
# Tipo vira o label da issue, então só os dois valores conhecidos passam.
[[ -n "$TITLE" ]] || { echo "Título (linha '# ...') não encontrado em $SPEC_PATH" >&2; exit 1; }
[[ "$STATUS" == "Aprovada" || "$STATUS" == "Aprovado" ]] || { echo "Spec com Status '$STATUS' (esperado 'Aprovada'): $SPEC_PATH" >&2; exit 1; }

case "$TIPO" in
  feature|improvement) ;;
  *) echo "Campo **Tipo** ausente ou inválido ('$TIPO') em $SPEC_PATH — use /spec para preencher feature|improvement" >&2; exit 1 ;;
esac

# Corpo da issue = spec inteira, mais um rodapé apontando de volta pro
# arquivo fonte. Sem resumir/reescrever nada — é isso que torna o script
# determinístico em vez de depender de interpretação do agente.
BODY="$(cat <<EOF
$(cat "$SPEC_PATH")

## Spec

\`${SPEC_PATH}\`
EOF
)"

# Cria a issue de fato. gh imprime a URL no stdout; o número da issue é
# só o último segmento dela (.../issues/42 → 42).
ISSUE_URL="$(gh issue create --title "$TITLE" --label "$TIPO" --body "$BODY")"
ISSUE_NUMBER="$(basename "$ISSUE_URL")"

# Fecha o ciclo: grava na própria spec que ela virou issue, pra não deixar
# rastro só na cabeça de quem rodou o comando. Status muda pra "Issue
# criada" e a linha **Issue**: #N é inserida (só na primeira vez — se já
# existir, não duplica).
sed -i -E "s/^\*\*Status\*\*: \`Aprovad[ao]\`(.*)$/\*\*Status\*\*: \`Issue criada\`\1/" "$SPEC_PATH"
if ! grep -q '^\*\*Issue\*\*:' "$SPEC_PATH"; then
  sed -i "/^\*\*Status\*\*:/a **Issue**: #${ISSUE_NUMBER}" "$SPEC_PATH"
fi

# Saída em formato KV — quem chamou o script (o /issue.prompt.md) lê essas
# linhas pra montar a mensagem de confirmação pro usuário.
echo "ISSUE_NUMBER=${ISSUE_NUMBER}"
echo "ISSUE_URL=${ISSUE_URL}"
echo "SPEC_PATH=${SPEC_PATH}"
