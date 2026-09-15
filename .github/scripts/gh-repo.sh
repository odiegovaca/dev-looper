#!/usr/bin/env bash
# gh-repo.sh
#
# Imprime o OWNER/REPO do remoto `origin`, para passar em --repo aos comandos gh:
# o fluxo inteiro empurra para `origin`, e o gh sem --repo resolve sozinho, num
# fork escolhendo o `upstream` — issue e PR iriam para o repositório de terceiro.
set -euo pipefail

URL="$(git remote get-url origin 2>/dev/null || true)"
if [ -z "$URL" ]; then
  echo "Remoto 'origin' não encontrado — o fluxo inteiro empurra para origin. Rode: git remote add origin <url>" >&2
  exit 1
fi

URL="${URL%/}"
URL="${URL%.git}"
# Últimos dois segmentos, com ':' (SSH) ou '/' (HTTPS) antes do owner.
REPO="$(printf '%s' "$URL" | sed -E 's#^.*[/:]([^/:]+)/([^/]+)$#\1/\2#')"

if [ "$REPO" = "$URL" ] || [ -z "$REPO" ]; then
  echo "Não consegui extrair OWNER/REPO da URL do origin ('$URL') — confira: git remote -v" >&2
  exit 1
fi

echo "$REPO"
