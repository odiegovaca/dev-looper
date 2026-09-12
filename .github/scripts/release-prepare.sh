#!/usr/bin/env bash
# release-prepare.sh [versão]
#
# Resolve tudo que o passo 1 do /release precisa, e deixa o CHANGELOG pronto
# para o passo 2 escrever (nenhuma decisão aqui depende de julgamento do agente).
#
# Imprime primeiro as variáveis, uma por linha em KEY=value:
# PROD_BRANCH/INTEGRATION_BRANCH/INTEGRATION_VERSION/RELEASE_VERSION.
# Depois dois blocos de texto, cada um aberto pelo próprio
# rótulo e terminado pelo rótulo seguinte ou pelo fim da saída (mesmo formato
# do "CHANGED_FILES:" em rc-prepare.sh): "RC_SECTIONS:" com o texto das
# seções de RC deste ciclo, na ordem em que aconteceram, e "COMMITS:" com os
# commits desde a última release. Só o bloco KEY=value serve para `eval`.
# RELEASE_VERSION é a versão definitiva, usada em todos os passos seguintes
# de /release.
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

# Commits desde a última release em produção — insumo somente-leitura para
# a consolidação do CHANGELOG no passo 2, que aí sim exige julgamento do agente.
COMMITS="$(git log "origin/$PROD_BRANCH..origin/$INTEGRATION_BRANCH" --oneline --no-merges)"

# O passo 2 do /release recebe o CHANGELOG num estado único, igual em toda
# rodada: a seção da release criada e vazia no topo, as seções de RC deste
# ciclo fora do arquivo, e o texto delas devolvido em RC_SECTIONS. Assim o
# passo 2 nunca renomeia header nem apaga seção — só escreve o corpo, do zero,
# a partir de RC_SECTIONS e COMMITS.
#
# RC_SECTIONS sai do CHANGELOG no merge-base com a integração, não do arquivo
# local: o local já perdeu as seções de RC numa rodada anterior, o merge-base
# não. É isso que faz a reexecução ser idêntica à primeira rodada, sem estado
# a comunicar ao passo 2. Se a branch de release mergear a integração depois,
# o merge-base avança e os RCs novos entram junto — mas esse merge conflita
# no próprio CHANGELOG.md (a branch de release apagou seções que a integração
# mantém) e precisa de resolução manual; depois dela, isto aqui funciona.
#
# "Este ciclo" são as seções -rc.N contíguas no topo da lista de versões. Uma
# seção de RC perdida abaixo da última release é defeito de outro ciclo, não
# deste — quem barra isso é o release-finalize.sh, antes do PR.
RC_SECTIONS=""
if [ -f CHANGELOG.md ]; then
  # A branch local de integração é o segundo lugar a olhar: em repo sem
  # remoto (ou com origin/ desatualizado), ela ainda tem as seções de RC.
  # O arquivo local só serve de último recurso — numa reexecução ele já é a
  # fonte errada, e daí RC_SECTIONS sai vazio em silêncio.
  BASE_REF=""
  for REF in "origin/$INTEGRATION_BRANCH" "$INTEGRATION_BRANCH"; do
    BASE_REF="$(git merge-base HEAD "$REF" 2>/dev/null || true)"
    [ -z "$BASE_REF" ] || break
  done
  BASE_CHANGELOG=""
  [ -z "$BASE_REF" ] || BASE_CHANGELOG="$(git show "$BASE_REF:CHANGELOG.md" 2>/dev/null || true)"
  [ -n "$BASE_CHANGELOG" ] || BASE_CHANGELOG="$(cat CHANGELOG.md)"

  RC_SECTIONS="$(echo "$BASE_CHANGELOG" | awk '
    /^## \[/ {
      if ($0 !~ /^## \[[^]]*-rc\./) exit
      incycle = 1
    }
    incycle { print }
  ')"

  # A seção da release é carimbada uma vez, quando ainda não existe; existindo,
  # o header fica como está (a data é a da criação) e só o corpo é esvaziado.
  HAS_REL=""
  if grep -q "^## \[$RELEASE_VERSION\]" CHANGELOG.md; then HAS_REL=1; fi
  HEADER="## [$RELEASE_VERSION] - $(date +%d/%m/%Y)"

  if grep -q '^## \[' CHANGELOG.md; then
    awk -v hdr="$HEADER" -v ver="## [$RELEASE_VERSION]" -v has_rel="$HAS_REL" '
      /^## \[/ {
        isrel = (index($0, ver) == 1)
        isrc  = ($0 ~ /^## \[[^]]*-rc\./)
        if (!has_rel && !inserted) { print hdr; print ""; inserted = 1 }
        if (isrel) { print; print ""; skip = 1; next }
        if (isrc && !passou) { skip = 1; next }
        passou = 1; skip = 0
        print; next
      }
      skip { next }
      { print }
    ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
  elif [ -z "$HAS_REL" ]; then
    { echo; echo "$HEADER"; } >> CHANGELOG.md
  fi
fi

echo "PROD_BRANCH=$PROD_BRANCH"
echo "INTEGRATION_BRANCH=$INTEGRATION_BRANCH"
echo "INTEGRATION_VERSION=$INTEGRATION_VERSION"
echo "RELEASE_VERSION=$RELEASE_VERSION"
echo "RC_SECTIONS:"
echo "$RC_SECTIONS"
echo "COMMITS:"
echo "$COMMITS"
