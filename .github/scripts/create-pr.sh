#!/usr/bin/env bash
# create-pr.sh <patch|minor|major> <título>
# Resumo do PR via stdin.
#
# Push da branch, checagem de PR já aberto, tipo→prefixo de commit convencional
# e `gh pr create`. Título e resumo vêm de fora porque exigem leitura dos commits.
# Branch base, versão e número da issue saem dos scripts que já os calcularam, não de argumento.
# Imprime a confirmação pronta para o chat — usar a saída sem alterações.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GH_REPO="$("$SCRIPT_DIR/gh-repo.sh")"

TIPO="${1:-}"
TITLE_DESC="${2:-}"

if [ -z "$TIPO" ] || [ -z "$TITLE_DESC" ]; then
  echo "Uso: create-pr.sh <patch|minor|major> <título>  (resumo via stdin)" >&2
  exit 1
fi

case "$TIPO" in
  patch) PREFIX="fix" ;;
  minor) PREFIX="feat" ;;
  major) PREFIX="feat!" ;;
  *) echo "Tipo inválido: $TIPO (use patch|minor|major)" >&2; exit 1 ;;
esac

BODY_SUMMARY="$(cat)"

BRANCHES="$("$SCRIPT_DIR/release-branches.sh")" || exit 1
eval "$BRANCHES"
NEW_VERSION="$("$SCRIPT_DIR/bump-version.sh" current)"
# Sem issue vinculada não há "Closes #N" — não é erro, é branch fora do padrão.
FEATURE_N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"

CURRENT_BRANCH="$(git branch --show-current)"
# -u deixa a branch com tracking, para os pushes seguintes à mão não precisarem de argumento.
git push -u origin "$CURRENT_BRANCH"

# Filtra por estado: sem isso, uma branch reaproveitada devolve o PR já mergeado
# e o script sai com 0.
EXISTING_PR="$(gh pr view --repo "$GH_REPO" "$CURRENT_BRANCH" --json url,state --jq 'select(.state == "OPEN") | .url' 2>/dev/null || true)"
if [ -n "$EXISTING_PR" ]; then
  echo "⚠️ Já existe um PR aberto para esta branch: $EXISTING_PR"
  echo "   Push aplicado com as mudanças mais recentes; nenhum PR novo foi criado."
  exit 0
fi

BODY="## Resumo
$BODY_SUMMARY"
if [ -n "$FEATURE_N" ]; then
  BODY="$BODY

Closes #$FEATURE_N"
fi

# --head explícito: com --repo o gh deixa de inferir a head do diretório atual.
PR_URL="$(gh pr create --repo "$GH_REPO" --base "$INTEGRATION_BRANCH" --head "$CURRENT_BRANCH" --title "$PREFIX: $TITLE_DESC" --body "$BODY")"

echo "✅ PR criado: $PR_URL"
echo "   Versão: $NEW_VERSION ($TIPO)"
echo "   Base: $INTEGRATION_BRANCH ← $CURRENT_BRANCH"
