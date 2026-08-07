#!/usr/bin/env bash
# release-prepare.sh [versão]
#
# Resolve tudo que o passo 1 do /release precisa antes da consolidação do
# CHANGELOG (nenhuma decisão aqui depende de julgamento do agente).
#
# Imprime PROD_BRANCH/INTEGRATION_BRANCH/INTEGRATION_VERSION/RELEASE_VERSION
# (uma var por linha, formato KEY=value — usar com
# `eval "$(release-prepare.sh "$ARGUMENTS")"`), seguido de "COMMITS:" e a
# lista de commits, um por linha (mesmo formato do "CHANGED_FILES:" em
# rc-prepare.sh). RELEASE_VERSION é a versão definitiva, usada em todos os
# passos seguintes de /release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERSION_ARG="${1:-}"
if [ -n "$VERSION_ARG" ] && ! [[ "$VERSION_ARG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Argumento inválido: $VERSION_ARG (use X.Y.Z, ex: 2.5.0)" >&2
  exit 1
fi

eval "$("$SCRIPT_DIR/release-branches.sh")"

# Checkout de branch não deve arrastar/perder trabalho em progresso.
if [ -n "$(git status --porcelain)" ]; then
  echo "Há mudanças não commitadas — commit ou stash antes de rodar /release." >&2
  exit 1
fi

# Troca para a branch de integração avisando sobre commits locais não
# mergeados. Exceção: se já estamos na própria branch de release desta
# [versão] (reexecução), pula a ida e volta — só serviria pra reler uma
# versão que já sabemos, e ainda emitiria um aviso de "commits não
# mergeados" sem sentido nesse contexto.
CURRENT_BRANCH="$(git branch --show-current)"
RELEASE_BRANCH_HINT="${VERSION_ARG:+release/v$VERSION_ARG}"
if [ "$CURRENT_BRANCH" != "$INTEGRATION_BRANCH" ] && [ "$CURRENT_BRANCH" != "$RELEASE_BRANCH_HINT" ]; then
  UNMERGED="$(git log "origin/$INTEGRATION_BRANCH..HEAD" --oneline 2>/dev/null || true)"
  [ -z "$UNMERGED" ] || echo "⚠️ Commits em $CURRENT_BRANCH não mergeados em $INTEGRATION_BRANCH — rode /rc primeiro se ainda não fez isso." >&2
  git checkout "$INTEGRATION_BRANCH"
  git pull origin "$INTEGRATION_BRANCH"
fi

# Numa reexecução pulando o bloco acima, isto lê a versão da própria branch
# de release (já sem -rc.N de uma tentativa anterior) em vez da RC original
# da integração — só usado como informativo, RELEASE_VERSION abaixo não
# depende disso quando VERSION_ARG foi passado.
INTEGRATION_VERSION="$("$SCRIPT_DIR/bump-version.sh" current)"
RELEASE_VERSION="${VERSION_ARG:-$(echo "$INTEGRATION_VERSION" | sed 's/-rc\..*//')}"

RELEASE_BRANCH="release/v$RELEASE_VERSION"
if git rev-parse --verify "$RELEASE_BRANCH" >/dev/null 2>&1; then
  git checkout "$RELEASE_BRANCH"
else
  git checkout -b "$RELEASE_BRANCH"
fi

"$SCRIPT_DIR/bump-version.sh" release "$RELEASE_VERSION" >/dev/null

# Commits desde a última release em produção — insumo somente-leitura para
# a consolidação do CHANGELOG no passo 2, que aí sim exige julgamento do agente.
COMMITS="$(git log "origin/$PROD_BRANCH..origin/$INTEGRATION_BRANCH" --oneline --no-merges)"

echo "PROD_BRANCH=$PROD_BRANCH"
echo "INTEGRATION_BRANCH=$INTEGRATION_BRANCH"
echo "INTEGRATION_VERSION=$INTEGRATION_VERSION"
echo "RELEASE_VERSION=$RELEASE_VERSION"
echo "COMMITS:"
echo "$COMMITS"
