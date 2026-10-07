#!/usr/bin/env bash
# create-issue.sh [spec-path]
#
# Cria ou atualiza a issue GitHub de uma spec: título e label saem da spec, o
# corpo é o arquivo inteiro. O campo **Issue** decide entre criar e atualizar.
# Sem spec-path, usa a única spec Aprovada de docs/issues/ (erro se zero ou várias).
# Imprime a confirmação pronta para o chat — usar a saída sem alterações.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GH_REPO="$("$SCRIPT_DIR/gh-repo.sh")"

SPEC_PATH="${1:-}"

# Sem argumento, precisa sobrar exatamente uma spec aprovada — zero ou várias é erro.
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

[[ -f "$SPEC_PATH" ]] || { echo "Spec não encontrada: $SPEC_PATH — confira o caminho, ou rode /spec para criar a spec" >&2; exit 1; }

# Campos do cabeçalho da spec: TITLE do H1, STATUS e TIPO das linhas "**Campo**: `valor`".
# `|| true` para campo ausente cair nas validações abaixo, não matar o script.
TITLE="$(grep -m1 '^# ' "$SPEC_PATH" | sed 's/^# //' || true)"
STATUS="$(grep -m1 '^\*\*Status\*\*:' "$SPEC_PATH" | sed -E 's/^\*\*Status\*\*:[[:space:]]*`([^`]+)`.*/\1/' || true)"
TIPO="$(grep -m1 '^\*\*Tipo\*\*:' "$SPEC_PATH" | sed -E 's/^\*\*Tipo\*\*:[[:space:]]*`([^`]+)`.*/\1/' || true)"

# O campo **Issue** é a chave, nunca o título ou o nome do arquivo — os dois mudam
# num refinamento, e abririam uma issue duplicada deixando a original órfã.
ISSUE_EXISTENTE="$(grep -m1 -E '^\*\*Issue\*\*: \[?#[0-9]+' "$SPEC_PATH" | sed -E 's/^\*\*Issue\*\*: \[?#([0-9]+).*/\1/' || true)"

[[ -n "$TITLE" ]] || { echo "Título (linha '# ...') não encontrado em $SPEC_PATH — acrescente o H1 do template, ou rode /spec para regravar a spec" >&2; exit 1; }

# Atualizar aceita também `Issue criada` — é o status em que uma spec refinada
# fica, e exigir `Aprovada` obrigaria a rebaixá-lo à mão só para propagar.
if [[ -n "$ISSUE_EXISTENTE" ]]; then
  case "$STATUS" in
    Aprovada|Aprovado|"Issue criada") ;;
    *) echo "Spec com Status '${STATUS:-ausente}' (esperado 'Aprovada' ou 'Issue criada'): $SPEC_PATH — use /spec [identificador] para aprovar" >&2; exit 1 ;;
  esac
else
  [[ "$STATUS" == "Aprovada" || "$STATUS" == "Aprovado" ]] || { echo "Spec com Status '${STATUS:-ausente}' (esperado 'Aprovada'): $SPEC_PATH — use /spec [identificador] para aprovar" >&2; exit 1; }
fi

case "$TIPO" in
  feature|improvement) ;;
  *) echo "Campo **Tipo** ausente ou inválido ('$TIPO') em $SPEC_PATH — use /spec para preencher feature|improvement" >&2; exit 1 ;;
esac

# Corpo da issue = spec inteira + rodapé apontando para o arquivo fonte.
BODY="$(cat <<EOF
$(cat "$SPEC_PATH")

## Spec

\`${SPEC_PATH}\`
EOF
)"

# Nenhum passo do /setup cria a label, e o --label abaixo a exige: sem isto o
# /issue falha na primeira execução de todo repositório novo. --force é idempotente.
gh label create "$TIPO" --repo "$GH_REPO" --force >/dev/null 2>&1 \
  || echo "⚠️ Não consegui garantir a label '$TIPO' em $GH_REPO — se o passo abaixo falhar por label ausente, rode: gh label create $TIPO --repo $GH_REPO" >&2

# gh imprime a URL nos dois casos; na criação o número é o último segmento dela.
if [[ -n "$ISSUE_EXISTENTE" ]]; then
  ISSUE_ACTION="updated"
  ISSUE_NUMBER="$ISSUE_EXISTENTE"
  ISSUE_URL="$(gh issue edit --repo "$GH_REPO" "$ISSUE_NUMBER" --title "$TITLE" --body "$BODY" --add-label "$TIPO")"
  # O Tipo pode ter mudado no refinamento: --add-label não tira o antigo, e como
  # só há dois valores o outro sai aqui (remover label ausente não é erro).
  OUTRO_TIPO="improvement"
  [[ "$TIPO" == "improvement" ]] && OUTRO_TIPO="feature"
  gh issue edit --repo "$GH_REPO" "$ISSUE_NUMBER" --remove-label "$OUTRO_TIPO" >/dev/null 2>&1 || true
else
  ISSUE_ACTION="created"
  ISSUE_URL="$(gh issue create --repo "$GH_REPO" --title "$TITLE" --label "$TIPO" --body "$BODY")"
  ISSUE_NUMBER="$(basename "$ISSUE_URL")"
fi

# Apaga e reinsere a linha **Issue** (em vez de editar no lugar) para reexecução
# não duplicá-la; os dois espaços no fim são o quebra-linha do Markdown.
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
