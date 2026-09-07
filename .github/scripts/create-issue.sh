#!/usr/bin/env bash
# create-issue.sh [spec-path]
#
# Cria ou atualiza a issue GitHub de uma spec. Título e label são extraídos
# da spec; o corpo é o conteúdo integral do arquivo — sem inferência do
# agente. Se a spec já traz o campo **Issue**, atualiza aquela issue em vez
# de abrir outra. Se spec-path for omitido, busca a única spec com
# Status: Aprovada em docs/issues/ (erro se houver zero ou mais de uma).
#
# Em caso de sucesso, imprime no stdout a mensagem de confirmação já pronta
# pro usuário — o /issue só repassa.
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
    echo "Nenhuma spec com Status: Aprovada encontrada em docs/issues/ — use /spec para aprovar uma" >&2
    exit 1
  elif [[ "${#CANDIDATES[@]}" -gt 1 ]]; then
    echo "Múltiplas specs aprovadas — rode de novo passando o caminho de uma:" >&2
    printf '%s\n' "${CANDIDATES[@]}" >&2
    exit 1
  fi
  SPEC_PATH="${CANDIDATES[0]}"
fi

[[ -f "$SPEC_PATH" ]] || { echo "Spec não encontrada: $SPEC_PATH" >&2; exit 1; }

# Lê os campos que o resto do script precisa, direto do texto da spec:
# TITLE vem do H1 (primeira linha "# ..."), STATUS e TIPO vêm das linhas
# "**Campo**: `valor`" do cabeçalho — mesmo formato usado no template do
# /spec, então o grep+sed funciona em qualquer spec gerada por ele.
TITLE="$(grep -m1 '^# ' "$SPEC_PATH" | sed 's/^# //')"
STATUS="$(grep -m1 '^\*\*Status\*\*:' "$SPEC_PATH" | sed -E 's/^\*\*Status\*\*:[[:space:]]*`([^`]+)`.*/\1/')"
TIPO="$(grep -m1 '^\*\*Tipo\*\*:' "$SPEC_PATH" | sed -E 's/^\*\*Tipo\*\*:[[:space:]]*`([^`]+)`.*/\1/')"

# É o campo **Issue** que diz se esta spec já virou issue — nunca o título
# nem o nome do arquivo. Mudar o título e renomear a spec são rotina num
# refinamento, e usar qualquer um dos dois como chave abriria uma issue
# duplicada, deixando a original órfã.
ISSUE_EXISTENTE="$(grep -m1 -E '^\*\*Issue\*\*: \[?#[0-9]+' "$SPEC_PATH" | sed -E 's/^\*\*Issue\*\*: \[?#([0-9]+).*/\1/' || true)"

# Validações: sem título não dá pra criar issue; Tipo vira o label da issue,
# então só os dois valores conhecidos passam.
[[ -n "$TITLE" ]] || { echo "Título (linha '# ...') não encontrado em $SPEC_PATH" >&2; exit 1; }

# Criar exige spec aprovada (aceita a variação "Aprovado" pra não travar em
# typo de gênero). Atualizar aceita também `Issue criada`, que é o status em
# que uma spec refinada fica — exigir `Aprovada` aqui obrigaria a rebaixar o
# status na mão só pra propagar o refinamento.
if [[ -n "$ISSUE_EXISTENTE" ]]; then
  case "$STATUS" in
    Aprovada|Aprovado|"Issue criada") ;;
    *) echo "Spec com Status '$STATUS' (esperado 'Aprovada' ou 'Issue criada'): $SPEC_PATH — use /spec [identificador] para aprovar" >&2; exit 1 ;;
  esac
else
  [[ "$STATUS" == "Aprovada" || "$STATUS" == "Aprovado" ]] || { echo "Spec com Status '$STATUS' (esperado 'Aprovada'): $SPEC_PATH — use /spec [identificador] para aprovar" >&2; exit 1; }
fi

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

# Cria ou atualiza, conforme a spec já tenha issue vinculada. gh imprime a
# URL no stdout nos dois casos; na criação o número da issue é só o último
# segmento dela (.../issues/42 → 42).
if [[ -n "$ISSUE_EXISTENTE" ]]; then
  ISSUE_ACTION="updated"
  ISSUE_NUMBER="$ISSUE_EXISTENTE"
  ISSUE_URL="$(gh issue edit "$ISSUE_NUMBER" --title "$TITLE" --body "$BODY" --add-label "$TIPO")"
  # O Tipo pode ter mudado no refinamento. --add-label é idempotente mas não
  # tira o label antigo; como só existem dois valores, o outro sai aqui.
  # Tolerante de propósito: remover label que não está lá não é erro, e não
  # pode derrubar uma atualização que já foi aplicada acima.
  OUTRO_TIPO="improvement"
  [[ "$TIPO" == "improvement" ]] && OUTRO_TIPO="feature"
  gh issue edit "$ISSUE_NUMBER" --remove-label "$OUTRO_TIPO" >/dev/null 2>&1 || true
else
  ISSUE_ACTION="created"
  ISSUE_URL="$(gh issue create --title "$TITLE" --label "$TIPO" --body "$BODY")"
  ISSUE_NUMBER="$(basename "$ISSUE_URL")"
fi

# Fecha o ciclo: grava na própria spec que ela virou issue. Os dois
# espaços no fim são o quebra-linha do Markdown: sem eles a linha renderiza
# grudada na **Tipo** logo abaixo.
sed -i -E "s/^\*\*Status\*\*: \`Aprovad[ao]\`(.*)$/\*\*Status\*\*: \`Issue criada\`\1/" "$SPEC_PATH"
sed -i '/^\*\*Issue\*\*:/d' "$SPEC_PATH"
sed -i "/^\*\*Status\*\*:/a **Issue**: [#${ISSUE_NUMBER}](${ISSUE_URL})  " "$SPEC_PATH"

if [[ "$ISSUE_ACTION" == "created" ]]; then
  echo "✅ Issue #${ISSUE_NUMBER} criada: ${ISSUE_URL}"
  echo "   Spec atualizada: ${SPEC_PATH} → Status: Issue criada"
  echo "   Próximo passo: /code para começar o desenvolvimento."
else
  echo "✅ Issue #${ISSUE_NUMBER} atualizada com a spec revisada: ${ISSUE_URL}"
  echo "   Título, corpo e label agora refletem ${SPEC_PATH}."
  echo "   Próximo passo: /code — se a implementação já começou, confira se os requisitos que mudaram invalidam algo já feito."
fi
