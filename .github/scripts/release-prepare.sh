#!/usr/bin/env bash
# release-prepare.sh [versão]
#
# Corta a branch de release, grava a versão estável e carimba o header no CHANGELOG.
# Imprime um relato do que fez — o release-finalize.sh relê branch e versão dos
# mesmos lugares em que este script as gravou, em vez de recebê-las de volta.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERSION_ARG="${1:-}"
if [ -n "$VERSION_ARG" ] && ! [[ "$VERSION_ARG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Argumento inválido: $VERSION_ARG (use X.Y.Z, ex: 2.5.0)" >&2
  exit 1
fi

eval "$("$SCRIPT_DIR/release-branches.sh")"

CURRENT_BRANCH="$(git branch --show-current)"
RELEASE_BRANCH_HINT="${VERSION_ARG:+release/v$VERSION_ARG}"

# Árvore suja bloqueia o checkout — exceto já na branch de release desta versão,
# onde ela é o resultado de uma rodada anterior, não trabalho do usuário.
if [ "$CURRENT_BRANCH" != "$RELEASE_BRANCH_HINT" ] && [ -n "$(git status --porcelain)" ]; then
  echo "Há mudanças não commitadas — commit ou stash antes de rodar /release." >&2
  case "$CURRENT_BRANCH" in
    release/v*) echo "   Se é reexecução desta release, rode com a versão: /release ${CURRENT_BRANCH#release/v}" >&2 ;;
  esac
  exit 1
fi

# Vai para a integração avisando de commits locais não mergeados; numa reexecução
# a ida e volta é pulada, que só releria uma versão já conhecida.
if [ "$CURRENT_BRANCH" != "$INTEGRATION_BRANCH" ] && [ "$CURRENT_BRANCH" != "$RELEASE_BRANCH_HINT" ]; then
  UNMERGED="$(git log "origin/$INTEGRATION_BRANCH..HEAD" --oneline 2>/dev/null || true)"
  [ -z "$UNMERGED" ] || echo "⚠️ Commits em $CURRENT_BRANCH não mergeados em $INTEGRATION_BRANCH — rode /rc primeiro se ainda não fez isso." >&2
  git checkout "$INTEGRATION_BRANCH"
  git pull origin "$INTEGRATION_BRANCH"
fi

# Numa reexecução isto lê a versão da própria branch de release, não a RC da
# integração — é informativo, e RELEASE_VERSION vem de VERSION_ARG nesse caso.
INTEGRATION_VERSION="$("$SCRIPT_DIR/bump-version.sh" current)"
RELEASE_VERSION="${VERSION_ARG:-$(echo "$INTEGRATION_VERSION" | sed 's/-rc\..*//')}"

RELEASE_BRANCH="release/v$RELEASE_VERSION"
if git rev-parse --verify "$RELEASE_BRANCH" >/dev/null 2>&1; then
  git checkout "$RELEASE_BRANCH"
else
  git checkout -b "$RELEASE_BRANCH"
fi

"$SCRIPT_DIR/bump-version.sh" release "$RELEASE_VERSION" >/dev/null

# Commit feito nesta branch não passou pelo /rc, então pode faltar no CHANGELOG.
# O commit do próprio /release é excluído pelo assunto, senão se auto-denunciaria.
INT_REF="origin/$INTEGRATION_BRANCH"
git rev-parse --verify -q "$INT_REF" >/dev/null || INT_REF="$INTEGRATION_BRANCH"
PROPRIOS="$(git log "$INT_REF..HEAD" --oneline --no-merges --invert-grep --grep="^chore: release v" 2>/dev/null || true)"
if [ -n "$PROPRIOS" ]; then
  echo "⚠️ Commit(s) nesta branch de release e ausentes de $INTEGRATION_BRANCH — confira se estão na seção do CHANGELOG:" >&2
  echo "$PROPRIOS" | sed 's/^/     /' >&2
fi

# Só troca o header -rc.N do topo pelo da release, sem apagar seção nenhuma — apagar
# aqui conflitaria com a integração em todo merge. Header já carimbado fica como está.
if [ -f CHANGELOG.md ] && ! grep -q "^## \[$RELEASE_VERSION\]" CHANGELOG.md; then
  awk -v hdr="## [$RELEASE_VERSION] - $(date +%d/%m/%Y)" '
    !carimbado && /^## \[[^]]*-rc\./ { print hdr; carimbado = 1; next }
    { print }
  ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
fi

echo "✅ Branch $RELEASE_BRANCH pronta para a release $RELEASE_VERSION."
echo "   Origem: $INTEGRATION_BRANCH, em $INTEGRATION_VERSION. Destino do PR: $PROD_BRANCH."
echo "   Versão gravada nos arquivos e header do CHANGELOG carimbado."
