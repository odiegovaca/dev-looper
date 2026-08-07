#!/usr/bin/env bash
# release-postmerge.sh <release-version>
#
# Passo 6 do /release — só deve ser chamado depois que o PR de release
# (passo 4) foi aprovado e mergeado em produção, nunca automaticamente
# durante o resto do fluxo. Idempotente: não recria tag nem republica se já
# existir.
set -euo pipefail

RELEASE_VERSION="${1:-}"
[ -n "$RELEASE_VERSION" ] || { echo "Uso: release-postmerge.sh <release-version>" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$("$SCRIPT_DIR/release-branches.sh")"

if [ -n "$(git status --porcelain)" ]; then
  echo "Há mudanças não commitadas — commit ou stash antes de rodar release-postmerge.sh." >&2
  exit 1
fi

git checkout "$PROD_BRANCH"
git pull origin "$PROD_BRANCH"

# Confere que a versão em produção já bate com RELEASE_VERSION antes de
# criar/publicar a tag: se o merge ainda não aconteceu, a tag ficaria
# apontando pro commit errado (código anterior ao release) e, uma vez
# publicada, corrigir isso exige forçar a recriação de uma ref pública —
# pior que só abortar aqui.
CURRENT_PROD_VERSION="$("$SCRIPT_DIR/bump-version.sh" current)"
if [ "$CURRENT_PROD_VERSION" != "$RELEASE_VERSION" ]; then
  echo "$PROD_BRANCH está em $CURRENT_PROD_VERSION, não $RELEASE_VERSION — o PR de release ainda não foi mergeado. Aborte e rode de novo depois do merge." >&2
  exit 1
fi

TAG="v$RELEASE_VERSION"
if git rev-parse --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG já existe localmente."
else
  git tag -a "$TAG" -m "Release $TAG"
fi

if git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG já publicada em origin — nada a fazer."
else
  git push origin "$TAG"
fi

git checkout "$INTEGRATION_BRANCH"
git pull origin "$INTEGRATION_BRANCH"
git merge "$PROD_BRANCH"
git push origin "$INTEGRATION_BRANCH"

echo "✅ Tag $TAG publicada e $INTEGRATION_BRANCH sincronizada com $PROD_BRANCH."
