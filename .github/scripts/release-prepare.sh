#!/usr/bin/env bash
# release-prepare.sh [versão]
#
# Resolve tudo que o passo 1 do /release precisa, e carimba o header da release
# no CHANGELOG (nenhuma decisão aqui depende de julgamento do agente).
#
# Imprime PROD_BRANCH/INTEGRATION_BRANCH/INTEGRATION_VERSION/RELEASE_VERSION,
# uma por linha em KEY=value. É relato do que foi feito, não insumo de passo
# seguinte: o release-finalize.sh deriva branch e versão dos mesmos lugares em
# que este script as leu e gravou, em vez de recebê-las de volta.
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

# Checkout de branch não deve arrastar/perder trabalho em progresso — mas só
# há checkout quando ainda não estamos na branch de release desta [versão].
# Estando nela, a árvore suja é o output do passo 1 de uma rodada anterior
# (versão + CHANGELOG), não trabalho do usuário — exigir commit/stash aqui
# travaria justamente a reexecução que o resto do script sabe tratar.
if [ "$CURRENT_BRANCH" != "$RELEASE_BRANCH_HINT" ] && [ -n "$(git status --porcelain)" ]; then
  echo "Há mudanças não commitadas — commit ou stash antes de rodar /release." >&2
  case "$CURRENT_BRANCH" in
    release/v*) echo "   Se é reexecução desta release, rode com a versão: /release ${CURRENT_BRANCH#release/v}" >&2 ;;
  esac
  exit 1
fi

# Troca para a branch de integração avisando sobre commits locais não
# mergeados. Exceção: se já estamos na própria branch de release desta
# [versão] (reexecução), pula a ida e volta — só serviria pra reler uma
# versão que já sabemos, e ainda emitiria um aviso de "commits não
# mergeados" sem sentido nesse contexto.
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

# Commit feito na própria branch de release não passou pelo /rc — e é o único
# jeito de algo entrar nesta release depois do corte —, então a linha dele pode
# não estar na seção do CHANGELOG. Aviso derivado em vez de um passo de prosa
# pedindo ao agente que confira: quem sabe o que escrever é quem fez o ajuste, e
# assunto de commit é fonte pior do que isso. O commit do próprio /release é
# excluído pelo assunto, senão ele se auto-denunciaria em toda reexecução.
INT_REF="origin/$INTEGRATION_BRANCH"
git rev-parse --verify -q "$INT_REF" >/dev/null || INT_REF="$INTEGRATION_BRANCH"
PROPRIOS="$(git log "$INT_REF..HEAD" --oneline --no-merges --invert-grep --grep="^chore: release v" 2>/dev/null || true)"
if [ -n "$PROPRIOS" ]; then
  echo "⚠️ Commit(s) nesta branch de release e ausentes de $INTEGRATION_BRANCH — confira se estão na seção do CHANGELOG:" >&2
  echo "$PROPRIOS" | sed 's/^/     /' >&2
fi

# A seção do ciclo já vem consolidada do /rc, então aqui só falta trocar o header
# do RC pelo da release e carimbar a data. Não há seção a apagar — e era a
# remoção delas que punha esta branch e a integração em intenções opostas no
# mesmo trecho do arquivo, fazendo todo merge entre as duas conflitar.
#
# Renomeia só a primeira seção -rc.N. Se sobrar outra abaixo, ou não houver
# nenhuma, quem reclama é o release-finalize.sh antes do PR — nada é inventado
# aqui. E a checagem de $RELEASE_VERSION torna a reexecução inócua: o header já
# carimbado fica como está, com a data da primeira rodada.
if [ -f CHANGELOG.md ] && ! grep -q "^## \[$RELEASE_VERSION\]" CHANGELOG.md; then
  awk -v hdr="## [$RELEASE_VERSION] - $(date +%d/%m/%Y)" '
    !carimbado && /^## \[[^]]*-rc\./ { print hdr; carimbado = 1; next }
    { print }
  ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
fi

echo "PROD_BRANCH=$PROD_BRANCH"
echo "INTEGRATION_BRANCH=$INTEGRATION_BRANCH"
echo "INTEGRATION_VERSION=$INTEGRATION_VERSION"
echo "RELEASE_VERSION=$RELEASE_VERSION"
