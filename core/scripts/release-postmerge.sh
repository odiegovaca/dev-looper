#!/usr/bin/env bash
# release-postmerge.sh <release-version>
#
# Encerra a entrega, depois que o PR de release já foi mergeado em produção:
# publica a tag, sincroniza a integração com produção e fecha o ciclo de cada
# issue da release (fecha a issue, arquiva a spec e os reviews).
# Idempotente — tag já publicada, issue já fechada e spec já arquivada não são erro.
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

# Confere a versão em produção antes da tag: sem o merge, ela apontaria para o
# commit errado, e recriar uma ref pública é pior do que abortar aqui.
CURRENT_PROD_VERSION="$("$SCRIPT_DIR/bump-version.sh" current)"
if [ "$CURRENT_PROD_VERSION" != "$RELEASE_VERSION" ]; then
  echo "$PROD_BRANCH está em $CURRENT_PROD_VERSION, não $RELEASE_VERSION — o PR de release ainda não foi mergeado. Aborte e rode de novo depois do merge." >&2
  exit 1
fi

TAG="v$RELEASE_VERSION"

# Fronteira da release anterior: delimita quais PRs de RC entraram neste ciclo.
# O --exclude segura a reexecução, em que a tag desta seria a própria fronteira.
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

ENCERRAMENTO=()

# Lido ainda em produção, a única cópia onde a seção está garantida: depois do
# merge abaixo, um conflito abortado deixaria a issue fechando sem a lista.
COMENTARIO="Entregue na $TAG."
if [ -f CHANGELOG.md ]; then
  # Casa por prefixo: o header da seção traz a data depois da versão.
  SECAO="$(awk -v hdr="## [$RELEASE_VERSION]" '
    index($0, hdr) == 1 { found=1; next }
    found && /^## / { exit }
    found { print }
  ' CHANGELOG.md 2>/dev/null | sed -e '/./,$!d' || true)"
  [ -z "$SECAO" ] || COMENTARIO="$COMENTARIO

$SECAO"
fi

git checkout "$INTEGRATION_BRANCH"
git pull origin "$INTEGRATION_BRANCH"

# O merge de volta só atualiza a integração com produção: o número do próximo ciclo
# é assunto do próximo /rc, que o deriva da versão de produção. Por isso os arquivos
# de versão ficam com o lado de produção, e o CHANGELOG com os dois blocos — o da
# release e o do ciclo que a integração abriu em paralelo.
resolve_sincronizacao() {
  local arq tmp
  while IFS= read -r arq; do
    [ -n "$arq" ] || continue
    if [ "$arq" = "CHANGELOG.md" ]; then
      # `=======` é sublinhado de título válido em Markdown: apagar as marcas de
      # conflito com sed corromperia o arquivo, então quem as separa é o git.
      tmp="$(mktemp -d)"
      git show ":1:$arq" > "$tmp/base" 2>/dev/null || : > "$tmp/base"
      git show ":2:$arq" > "$tmp/nosso"
      git show ":3:$arq" > "$tmp/deles"
      git merge-file --union -p "$tmp/nosso" "$tmp/base" "$tmp/deles" \
        | awk 'NR > 1 && /^## / && anterior != "" { print "" } { print; anterior = $0 }' > "$arq"
      rm -rf "$tmp"
    else
      git checkout --theirs -- "$arq"
    fi
    git add "$arq"
  done
}

SINCRONIZADA=1
if ! git merge "$PROD_BRANCH"; then
  CONFLITADOS="$(git diff --name-only --diff-filter=U)"
  ESPERADOS="$(printf 'CHANGELOG.md\n%s\n' "$("$SCRIPT_DIR/bump-version.sh" files 2>/dev/null || true)")"
  INESPERADOS="$(grep -vxF -f <(printf '%s\n' "$ESPERADOS") <<< "$CONFLITADOS" || true)"

  if [ -n "$INESPERADOS" ]; then
    # Conflito fora do par CHANGELOG/versão é divergência de verdade entre as duas
    # branches, e resolver sozinho descartaria trabalho de alguém.
    git merge --abort || true
    SINCRONIZADA=""
    ENCERRAMENTO+=("⚠️ Merge de $PROD_BRANCH em $INTEGRATION_BRANCH conflitou fora do CHANGELOG e dos arquivos de versão, e foi abortado — resolva à mão (git merge $PROD_BRANCH) e commite: $(tr '\n' ' ' <<< "$INESPERADOS")")
    ENCERRAMENTO+=("   A tag e o encerramento das issues abaixo não dependem disso.")
  else
    resolve_sincronizacao <<< "$CONFLITADOS"
    git commit -q -m "chore: sincroniza $INTEGRATION_BRANCH com $PROD_BRANCH após a $TAG"
    ENCERRAMENTO+=("ℹ️ Merge de volta conflitou no esperado e foi resolvido: versão de $PROD_BRANCH, CHANGELOG com os dois blocos. O número do próximo ciclo sai do próximo /rc.")
  fi
fi

ISSUES=""
# Daqui para baixo a tag já está publicada: nada pode matar o script, só virar aviso.
GH_REPO=""
if ! command -v gh >/dev/null 2>&1; then
  ENCERRAMENTO+=("⚠️ Issues não encerradas: gh não encontrado. Feche e arquive manualmente.")
elif ! GH_REPO="$("$SCRIPT_DIR/gh-repo.sh" 2>/dev/null)"; then
  ENCERRAMENTO+=("⚠️ Issues não encerradas: não resolvi o OWNER/REPO do remoto origin. Feche e arquive manualmente.")
else
  # PRs mergeados na integração depois da release anterior; sem ela, todos. A fronteira
  # sai do epoch (%ct) e vira Z, porque só dá para comparar ISO-8601 dentro do mesmo fuso.
  SINCE=""
  if [ -n "$PREV_TAG" ]; then
    SINCE_EPOCH="$(git log -1 --format=%ct "$PREV_TAG" 2>/dev/null || true)"
    [ -z "$SINCE_EPOCH" ] || SINCE="$(date -u -d "@$SINCE_EPOCH" +%Y-%m-%dT%H:%M:%SZ)"
  fi
  # Comparação de string: ISO-8601 em UTC ordena lexicograficamente, então `>` é "mergeado depois".
  if [ -n "$SINCE" ]; then
    JQ_FILTER="map(select(.mergedAt > \"$SINCE\")) | .[].headRefName"
  else
    JQ_FILTER=".[].headRefName"
  fi
  # O {N} sai do nome da branch: o closingIssuesReferences do GitHub só vem preenchido
  # em PR baseado na branch default, e todo PR de RC aponta para a integração.
  BRANCHES_PR="$(gh pr list --repo "$GH_REPO" --base "$INTEGRATION_BRANCH" --state merged --limit 100 \
    --json headRefName,mergedAt --jq "$JQ_FILTER" 2>/dev/null || true)"
  ISSUES="$(printf '%s\n' "$BRANCHES_PR" | sed -nE 's#^[a-z]+/([0-9]+)-.*#\1#p' | sort -un || true)"
  # Nomeia como descartadas as branches fora do padrão
  DESCARTADAS="$(printf '%s\n' "$BRANCHES_PR" | grep -vE '^[a-z]+/[0-9]+-' | grep -v '^$' || true)"
  if [ -n "$DESCARTADAS" ]; then
    ENCERRAMENTO+=("⚠️ PR(s) mergeado(s) no ciclo com branch fora do padrão {tipo}/{N}-nome, sem issue a fechar: $(printf '%s' "$DESCARTADAS" | tr '\n' ' '). Confira manualmente.")
  fi
  [ -n "$ISSUES" ] || ENCERRAMENTO+=("⚠️ Não consegui descobrir as issues do ciclo: nenhum PR mergeado em $INTEGRATION_BRANCH desde ${PREV_TAG:-o início} tem branch no padrão {tipo}/{N}-nome. Feche e arquive manualmente.")
fi

for N in $ISSUES; do
  ESTADO="$(gh issue view --repo "$GH_REPO" "$N" --json state -q .state 2>/dev/null || true)"
  if [ "$ESTADO" = "CLOSED" ]; then
    ENCERRAMENTO+=("Issue #$N já estava fechada.")
  elif [ -z "$ESTADO" ]; then
    ENCERRAMENTO+=("⚠️ Issue #$N não consultada (gh falhou). Feche manualmente.")
  elif gh issue close --repo "$GH_REPO" "$N" --comment "$COMENTARIO" >/dev/null 2>&1; then
    ENCERRAMENTO+=("Issue #$N fechada.")
  else
    ENCERRAMENTO+=("⚠️ Issue #$N não fechada (gh falhou). Feche manualmente.")
  fi

  # Spec resolvida pelo campo **Issue**, nunca pelo nome do arquivo; o `([^0-9]|$)`
  # impede que #3 case com #30.
  SPEC="$(grep -lE "^\*\*Issue\*\*: \[?#${N}([^0-9]|$)" docs/issues/spec-*.md 2>/dev/null | head -1 || true)"
  if [ -z "$SPEC" ]; then
    # Olhar em arquivo/ separa a reexecução normal do defeito de formato.
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

  # Vão todos os {seq} do ciclo de uma vez — não há um "relatório final" a preservar.
  REVIEWS="$(ls docs/reviews/review-"${N}"-*.md 2>/dev/null || true)"
  if [ -n "$REVIEWS" ]; then
    if mkdir -p docs/reviews/arquivo 2>/dev/null && echo "$REVIEWS" | xargs -r -I{} mv {} docs/reviews/arquivo/ 2>/dev/null; then
      ENCERRAMENTO+=("Reviews arquivados: $(echo "$REVIEWS" | wc -l | tr -d ' ') da issue #$N")
    else
      ENCERRAMENTO+=("⚠️ Reviews da issue #$N não arquivados. Mova docs/reviews/review-$N-*.md para docs/reviews/arquivo/ manualmente.")
    fi
  fi
done

# Onde docs/ é gitignorado nada fica staged e isto não faz nada, sem precisar saber qual caso é.
git add -A docs/issues docs/reviews >/dev/null 2>&1 || true
git diff --cached --quiet || git commit -m "chore: arquiva specs e reviews entregues na $TAG"

git push origin "$INTEGRATION_BRANCH"

if [ -n "$SINCRONIZADA" ]; then
  echo "✅ Tag $TAG publicada e $INTEGRATION_BRANCH sincronizada com $PROD_BRANCH."
else
  echo "✅ Tag $TAG publicada. $INTEGRATION_BRANCH ainda NÃO sincronizada com $PROD_BRANCH (ver abaixo)."
fi
if [ "${#ENCERRAMENTO[@]}" -gt 0 ]; then
  for LINHA in "${ENCERRAMENTO[@]}"; do
    echo "   $LINHA"
  done
fi
