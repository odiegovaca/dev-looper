#!/usr/bin/env bash
# create-pr.sh <patch|minor|major> <título>
# Resumo do PR via stdin.
#
# Faz a parte 100% mecânica do passo 4 do /rc: push da branch atual, checagem
# de PR já aberto (sem criar duplicado nem editar automaticamente — só
# reporta), mapeamento tipo→prefixo de commit convencional e a chamada ao
# `gh pr create`. Título e resumo continuam vindo de fora porque exigem
# leitura dos commits — o script não infere nada, só monta e executa.
#
# Branch base, versão e número da issue não entram por argumento: saem dos
# mesmos scripts que já os calcularam no passo 1. Recebê-los de novo era o
# mesmo estado atravessando o contexto do agente entre um passo e outro.
#
# Termina imprimindo a confirmação já pronta para colar no chat (mesmo
# padrão do review-finalize.sh) — usar a saída sem alterações.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
# Sem issue vinculada a branch não há "Closes #N" — não é erro, é um /rc de
# branch fora do padrão {tipo}/{N}-nome.
FEATURE_N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"

CURRENT_BRANCH="$(git branch --show-current)"
git push origin "$CURRENT_BRANCH"

# Só PR aberto conta. Sem o filtro de estado, o `gh pr view` de uma branch
# reaproveitada devolve o PR já mergeado, e o script reportaria "já existe um PR
# aberto" e sairia com 0 — o /rc mostraria sucesso sem PR nenhum criado.
EXISTING_PR="$(gh pr view "$CURRENT_BRANCH" --json url,state --jq 'select(.state == "OPEN") | .url' 2>/dev/null || true)"
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
