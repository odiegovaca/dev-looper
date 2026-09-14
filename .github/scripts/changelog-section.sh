#!/usr/bin/env bash
# changelog-section.sh <versão>
#
# Garante no topo do CHANGELOG.md uma única seção de ciclo com o header na versão
# dada e `Unreleased` no lugar da data. Cria o arquivo e a seção na primeira vez;
# depois só troca o header, preservando o corpo. As subseções são do /rc — quem
# sabe em qual categoria do Keep a Changelog cada mudança entra é quem a fez.
set -euo pipefail

VERSION="${1:-}"
[ -n "$VERSION" ] || { echo "Uso: changelog-section.sh <versão>  (a versão vem do bump-version.sh)" >&2; exit 1; }

HEADER="## [$VERSION] - Unreleased"

if [ ! -f CHANGELOG.md ]; then
  printf '# Changelog\n\n%s\n\n' "$HEADER" > CHANGELOG.md
  echo "CHANGELOG.md criado com a seção $VERSION — preencha os itens do ciclo."
  exit 0
fi

# A seção do ciclo é sempre a primeira "## [": se ela ainda não foi publicada
# (traz -rc.N ou Unreleased), só o header muda; senão entra uma seção nova acima.
PRIMEIRA="$(grep -m1 '^## \[' CHANGELOG.md || true)"

case "$PRIMEIRA" in
  "")
    printf '%s\n\n' "$HEADER" | cat - CHANGELOG.md > CHANGELOG.md.tmp
    mv CHANGELOG.md.tmp CHANGELOG.md
    echo "Seção $VERSION criada no topo do CHANGELOG.md — preencha os itens do ciclo."
    ;;
  *-rc.*|*Unreleased*)
    awk -v hdr="$HEADER" '!trocado && /^## \[/ { print hdr; trocado = 1; next } { print }' \
      CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
    echo "Header da seção do ciclo atualizado para $VERSION — reescreva o corpo com o delta acumulado."
    ;;
  *)
    INICIO="$(grep -n '^## \[' CHANGELOG.md | head -1 | cut -d: -f1)"
    {
      head -n "$((INICIO - 1))" CHANGELOG.md
      printf '%s\n\n' "$HEADER"
      tail -n "+$INICIO" CHANGELOG.md
    } > CHANGELOG.md.tmp
    mv CHANGELOG.md.tmp CHANGELOG.md
    echo "Seção $VERSION criada acima da última release — preencha os itens do ciclo."
    ;;
esac
