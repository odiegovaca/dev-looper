#!/usr/bin/env bash
# release-finalize.sh <prod-branch> <release-version>
# Resumo do PR via stdin.
#
# Faz a parte 100% mecânica do passo 6 do /release: commit das mudanças de
# versão/CHANGELOG (sem falhar se não houver nada staged), push da branch
# atual, checagem de PR já aberto (sem criar duplicado nem editar
# automaticamente — só reporta, mesmo padrão do create-pr.sh) e a chamada
# ao `gh pr create` com o checklist padrão de release.
#
# Termina imprimindo a confirmação já pronta para colar no chat (mesmo
# padrão do create-pr.sh) — usar a saída sem alterações.
set -euo pipefail

PROD_BRANCH="${1:-}"
RELEASE_VERSION="${2:-}"

if [ -z "$PROD_BRANCH" ] || [ -z "$RELEASE_VERSION" ]; then
  echo "Uso: release-finalize.sh <prod-branch> <release-version>  (resumo via stdin)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BODY_SUMMARY="$(cat)"

git add .
"$SCRIPT_DIR/protect-stage.sh"
git diff --cached --quiet || git commit -m "chore: release v$RELEASE_VERSION"

CURRENT_BRANCH="$(git branch --show-current)"
git push origin "$CURRENT_BRANCH"

EXISTING_PR="$(gh pr view "$CURRENT_BRANCH" --json url --jq .url 2>/dev/null || true)"
if [ -n "$EXISTING_PR" ]; then
  echo "⚠️ Já existe um PR aberto para esta branch: $EXISTING_PR"
  echo "   Push aplicado com as mudanças mais recentes; nenhum PR novo foi criado."
  exit 0
fi

BODY="## Release v$RELEASE_VERSION

### Resumo das mudanças
$BODY_SUMMARY

### Checklist
- [x] Todos os testes passando
- [x] CHANGELOG consolidado
- [x] Versões atualizadas
- [ ] Revisado por pelo menos 1 desenvolvedor"

PR_URL="$(gh pr create --base "$PROD_BRANCH" --title "release: v$RELEASE_VERSION" --body "$BODY")"

echo "✅ PR criado: $PR_URL"
echo "   Versão: $RELEASE_VERSION"
echo "   Base: $PROD_BRANCH ← $CURRENT_BRANCH"
