#!/usr/bin/env bash
# release-postmerge.sh <release-version>
#
# Encerramento do /release — só deve ser chamado depois que o PR de release
# (passo 4) foi aprovado e mergeado em produção, nunca automaticamente
# durante o resto do fluxo. É oferecido ao usuário como texto na saída do
# release-finalize.sh, e rodado a pedido dele. Idempotente: não recria tag nem republica se já
# existir, e não reclama de issue já fechada nem de spec já arquivada.
#
# É aqui que a entrega termina: publica a tag, sincroniza a integração com
# produção e encerra o ciclo de cada issue da release (fecha a issue, arquiva
# a spec e os relatórios de review).
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

# Fronteira da release anterior, lida antes de criar a tag desta — é o que
# delimita quais PRs de RC entraram neste ciclo. O --exclude é o que mantém
# isto correto numa reexecução: sem ele, a tag já criada seria a própria
# fronteira e a lista de issues sairia vazia.
PREV_TAG="$(git describe --tags --abbrev=0 --exclude "$TAG" 2>/dev/null || true)"

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

ENCERRAMENTO=()

COMENTARIO="Entregue na $TAG."
if [ -f CHANGELOG.md ]; then
  # index()==1 em vez de regex dinâmico
  SECAO="$(awk -v hdr="## [$RELEASE_VERSION]" '
    index($0, hdr) == 1 { found=1; next }
    found && /^## / { exit }
    found { print }
  ' CHANGELOG.md 2>/dev/null | sed -e '/./,$!d' || true)"
  [ -z "$SECAO" ] || COMENTARIO="$COMENTARIO

$SECAO"
fi

ISSUES=""
if ! command -v gh >/dev/null 2>&1; then
  ENCERRAMENTO+=("⚠️ Issues não encerradas: gh não encontrado. Feche e arquive manualmente.")
else
  # Recorte: PRs mergeados na integração
  # depois do commit da release anterior; sem release anterior, todos.
  SINCE=""
  [ -z "$PREV_TAG" ] || SINCE="$(git log -1 --format=%cI "$PREV_TAG" 2>/dev/null || true)"
  if [ -n "$SINCE" ]; then
    JQ_FILTER="map(select(.mergedAt > \"$SINCE\")) | .[].closingIssuesReferences[].number"
  else
    JQ_FILTER=".[].closingIssuesReferences[].number"
  fi
  ISSUES="$(gh pr list --base "$INTEGRATION_BRANCH" --state merged --limit 100 \
    --json closingIssuesReferences,mergedAt --jq "$JQ_FILTER" 2>/dev/null | sort -un || true)"
  [ -n "$ISSUES" ] || ENCERRAMENTO+=("⚠️ Nenhuma issue encontrada nos PRs mergeados em $INTEGRATION_BRANCH desde ${PREV_TAG:-o início}. Feche e arquive manualmente.")
fi

for N in $ISSUES; do
  ESTADO="$(gh issue view "$N" --json state -q .state 2>/dev/null || true)"
  if [ "$ESTADO" = "CLOSED" ]; then
    ENCERRAMENTO+=("Issue #$N já estava fechada.")
  elif [ -z "$ESTADO" ]; then
    ENCERRAMENTO+=("⚠️ Issue #$N não consultada (gh falhou). Feche manualmente.")
  elif gh issue close "$N" --comment "$COMENTARIO" >/dev/null 2>&1; then
    ENCERRAMENTO+=("Issue #$N fechada.")
  else
    ENCERRAMENTO+=("⚠️ Issue #$N não fechada (gh falhou). Feche manualmente.")
  fi

  # Spec: resolvida pelo campo **Issue** do cabeçalho, nunca pelo nome do
  # arquivo. O `([^0-9]|$)` impede que #3 case com #30.
  SPEC="$(grep -lE "^\*\*Issue\*\*: \[?#${N}([^0-9]|$)" docs/issues/spec-*.md 2>/dev/null | head -1 || true)"
  if [ -z "$SPEC" ]; then
    # Não achar a spec na raiz é o estado normal de uma reexecução, e defeito
    # em qualquer outro caso — o arquivo/ é o que separa os dois. Sem essa
    # distinção, rodar este script duas vezes acusaria um problema inexistente.
    if grep -lqE "^\*\*Issue\*\*: \[?#${N}([^0-9]|$)" docs/issues/arquivo/spec-*.md 2>/dev/null; then
      ENCERRAMENTO+=("Spec da issue #$N já estava arquivada.")
    else
      ENCERRAMENTO+=("⚠️ Spec da issue #$N não encontrada em docs/issues/ — campo **Issue** ausente ou formato alterado. Arquive manualmente.")
    fi
  elif mkdir -p docs/issues/arquivo 2>/dev/null && mv "$SPEC" docs/issues/arquivo/ 2>/dev/null; then
    ENCERRAMENTO+=("Spec arquivada: $(basename "$SPEC")")
  else
    ENCERRAMENTO+=("⚠️ Spec $(basename "$SPEC") não arquivada. Mova para docs/issues/arquivo/ manualmente.")
  fi

  # Relatórios de review: resolvidos pelo {N} do próprio nome, e vão todos os
  # {seq} do ciclo de uma vez — não há um "relatório final" a preservar.
  REVIEWS="$(ls docs/reviews/review-"${N}"-*.md 2>/dev/null || true)"
  if [ -n "$REVIEWS" ]; then
    if mkdir -p docs/reviews/arquivo 2>/dev/null && echo "$REVIEWS" | xargs -r -I{} mv {} docs/reviews/arquivo/ 2>/dev/null; then
      ENCERRAMENTO+=("Reviews arquivados: $(echo "$REVIEWS" | wc -l | tr -d ' ') da issue #$N")
    else
      ENCERRAMENTO+=("⚠️ Reviews da issue #$N não arquivados. Mova docs/reviews/review-$N-*.md para docs/reviews/arquivo/ manualmente.")
    fi
  fi
done

# Só entra em commit se docs/ for versionado no projeto — onde a pasta é
# gitignorada (o arquivamento é um mv local), nada é staged e isto não faz
# nada, sem precisar saber qual dos dois casos é.
git add -A docs/issues docs/reviews >/dev/null 2>&1 || true
git diff --cached --quiet || git commit -m "chore: arquiva specs e reviews entregues na $TAG"

git push origin "$INTEGRATION_BRANCH"

echo "✅ Tag $TAG publicada e $INTEGRATION_BRANCH sincronizada com $PROD_BRANCH."
if [ "${#ENCERRAMENTO[@]}" -gt 0 ]; then
  for LINHA in "${ENCERRAMENTO[@]}"; do
    echo "   $LINHA"
  done
fi
