#!/usr/bin/env bash
# install.sh <caminho-do-projeto> [--force]
#
# Instala/atualiza os arquivos do dev-looper (.github/) num projeto de destino
# sem sobrescrever customizações locais: por arquivo, se o destino já existe e
# difere do que está sendo instalado, pula e reporta. Só sobrescreve com --force.
set -euo pipefail

DEST=""
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    *) DEST="$arg" ;;
  esac
done

if [ -z "$DEST" ]; then
  echo "Uso: install.sh <caminho-do-projeto> [--force]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/../.." && pwd)/.github"
DEST_GITHUB="$DEST/.github"

mkdir -p "$DEST_GITHUB"

COPIED=()
SKIPPED=()

while IFS= read -r -d '' file; do
  rel="${file#"$SRC"/}"
  dest_file="$DEST_GITHUB/$rel"
  mkdir -p "$(dirname "$dest_file")"

  if [ -f "$dest_file" ]; then
    if cmp -s "$file" "$dest_file"; then
      continue
    fi
    if [ "$FORCE" = true ]; then
      cp "$file" "$dest_file"
      COPIED+=("$rel (sobrescrito)")
    else
      SKIPPED+=("$rel")
    fi
  else
    cp "$file" "$dest_file"
    COPIED+=("$rel")
  fi
done < <(find "$SRC" -type f -print0)

echo "Instalados/atualizados: ${#COPIED[@]}"
if [ "${#COPIED[@]}" -gt 0 ]; then
  printf '  %s\n' "${COPIED[@]}"
fi

if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo ""
  echo "Pulados (já existem e diferem do que está sendo instalado — use --force para sobrescrever): ${#SKIPPED[@]}"
  printf '  %s\n' "${SKIPPED[@]}"
fi
