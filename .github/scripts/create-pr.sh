#!/usr/bin/env bash
# create-pr.sh <integration-branch> <patch|minor|major> <new-version> <título> [feature-n]
# Resumo do PR via stdin.
#
# Faz a parte 100% mecânica do passo 4 do /rc: push da branch atual, checagem
# de PR já aberto (sem criar duplicado nem editar automaticamente — só
# reporta), mapeamento tipo→prefixo de commit convencional e a chamada ao
# `gh pr create`. Título e resumo continuam vindo de fora porque exigem
# leitura dos commits — o script não infere nada, só monta e executa.
#
# Termina imprimindo a confirmação já pronta para colar no chat (mesmo
# padrão do review-finalize.sh) — usar a saída sem alterações.
set -euo pipefail

INTEGRATION_BRANCH="${1:-}"
TIPO="${2:-}"
NEW_VERSION="${3:-}"
TITLE_DESC="${4:-}"
FEATURE_N="${5:-}"

if [ -z "$INTEGRATION_BRANCH" ] || [ -z "$TIPO" ] || [ -z "$NEW_VERSION" ] || [ -z "$TITLE_DESC" ]; then
  echo "Uso: create-pr.sh <integration-branch> <patch|minor|major> <new-version> <título> [feature-n]  (resumo via stdin)" >&2
  exit 1
fi

case "$TIPO" in
  patch) PREFIX="fix" ;;
  minor) PREFIX="feat" ;;
  major) PREFIX="feat!" ;;
  *) echo "Tipo inválido: $TIPO (use patch|minor|major)" >&2; exit 1 ;;
esac

BODY_SUMMARY="$(cat)"

CURRENT_BRANCH="$(git branch --show-current)"
git push origin "$CURRENT_BRANCH"

EXISTING_PR="$(gh pr view "$CURRENT_BRANCH" --json url --jq .url 2>/dev/null || true)"
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

PR_URL="$(gh pr create --base "$INTEGRATION_BRANCH" --title "$PREFIX: $TITLE_DESC" --body "$BODY")"

echo "✅ PR criado: $PR_URL"
echo "   Versão: $NEW_VERSION ($TIPO)"
echo "   Base: $INTEGRATION_BRANCH ← $CURRENT_BRANCH"
