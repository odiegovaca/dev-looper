#!/usr/bin/env bash
# bump-version.sh <patch|minor|major|release|current>
#
# Lê e grava a versão do projeto nos arquivos de versão configurados abaixo.
# `current` só lê e imprime, sem gravar. `patch/minor/major` calculam a
# próxima X.Y.Z-rc.N. `release` remove o sufixo -rc.N.
# Imprime só a versão resultante no stdout — capture com NEW_VERSION=$(bump-version.sh patch).
#
# VERSION_FILES é preenchido por /setup com os arquivos de versão detectados no Step 1.
set -euo pipefail

VERSION_FILES=(
  # [DEFINIR: ex. "package.json" "package-lock.json"]
)

ACTION="${1:-}"
[ -n "$ACTION" ] || { echo "Uso: bump-version.sh <patch|minor|major|release|current>" >&2; exit 1; }
[ "${#VERSION_FILES[@]}" -gt 0 ] || { echo "VERSION_FILES não configurado — rode /setup" >&2; exit 1; }

read_version() {
  local file="$1"
  case "$file" in
    *.json)
      grep -m1 '"version"' "$file" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
      ;;
    *.xml)
      grep -m1 '<version>' "$file" | sed -E 's/.*<version>([^<]+)<\/version>.*/\1/'
      ;;
    *.toml)
      grep -m1 '^version' "$file" | sed -E 's/version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/'
      ;;
    *)
      cat "$file"
      ;;
  esac
}

write_version() {
  local file="$1" new="$2"
  case "$file" in
    *.json)
      sed -i -E "0,/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]+\"/s//\"version\": \"$new\"/" "$file"
      ;;
    *.xml)
      sed -i -E "0,/<version>[^<]+<\/version>/s//<version>$new<\/version>/" "$file"
      ;;
    *.toml)
      sed -i -E "0,/^version[[:space:]]*=[[:space:]]*\"[^\"]+\"/s//version = \"$new\"/" "$file"
      ;;
    *)
      printf '%s' "$new" > "$file"
      ;;
  esac
}

CURRENT="$(read_version "${VERSION_FILES[0]}")"

if [ "$ACTION" = "current" ]; then
  echo "$CURRENT"
  exit 0
fi

BASE="${CURRENT%%-rc.*}"
MAJOR="$(echo "$BASE" | cut -d. -f1)"
MINOR="$(echo "$BASE" | cut -d. -f2)"
PATCH="$(echo "$BASE" | cut -d. -f3)"

case "$ACTION" in
  release)
    NEW="$BASE"
    ;;
  patch|minor|major)
    if [[ "$CURRENT" == *-rc.* ]]; then
      # já em RC (o bump de base já foi aplicado ao sair da versão estável): só incrementa o rc
      RC_N="${CURRENT##*-rc.}"
      NEW="$BASE-rc.$((RC_N+1))"
    else
      case "$ACTION" in
        patch) NEW="$MAJOR.$MINOR.$((PATCH+1))-rc.1" ;;
        minor) NEW="$MAJOR.$((MINOR+1)).0-rc.1" ;;
        major) NEW="$((MAJOR+1)).0.0-rc.1" ;;
      esac
    fi
    ;;
  *)
    echo "Ação inválida: $ACTION (use patch|minor|major|release|current)" >&2
    exit 1
    ;;
esac

for f in "${VERSION_FILES[@]}"; do
  write_version "$f" "$NEW"
done

echo "$NEW"
