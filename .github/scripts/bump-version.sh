#!/usr/bin/env bash
# bump-version.sh <patch|minor|major|release|current> [versão]
#
# Lê e grava a versão do projeto nos arquivos de versão configurados abaixo.
# Imprime só a versão resultante no stdout — capture com NEW_VERSION=$(bump-version.sh patch).
set -euo pipefail

# Preenchido por /setup com os arquivos de versão detectados no Passo 1.
VERSION_FILES=(
  # [DEFINIR: ex. "package.json" "package-lock.json" | "pyproject.toml" | "pom.xml" | "Cargo.toml"]
)

ACTION="${1:-}"
VERSION_ARG="${2:-}"
[ -n "$ACTION" ] || { echo "Uso: bump-version.sh <patch|minor|major|release|current> [versão]" >&2; exit 1; }
[ "${#VERSION_FILES[@]}" -gt 0 ] || { echo "VERSION_FILES não configurado — rode /setup" >&2; exit 1; }
if [ -n "$VERSION_ARG" ] && [ "$ACTION" != "release" ]; then
  echo "[versão] só é aceito com a ação 'release'" >&2
  exit 1
fi
if [ -n "$VERSION_ARG" ] && ! [[ "$VERSION_ARG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versão inválida: $VERSION_ARG (use X.Y.Z, ex: 2.5.0)" >&2
  exit 1
fi

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

# `current` só lê e imprime, sem gravar nada.
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
    # Remove o sufixo -rc.N. Se [versão] foi passada (override do usuário em
    # /release), grava essa versão em vez de só derivar da atual — evita
    # branch/PR nomeados com uma versão e arquivos gravados com outra.
    if [ -n "$VERSION_ARG" ]; then
      # Rejeita [versão] menor que a atual — evita publicar uma tag pública
      # "regressiva". Igual à atual é permitido, pra não quebrar reexecução
      # idempotente.
      SMALLER="$(printf '%s\n%s\n' "$BASE" "$VERSION_ARG" | sort -V | head -1)"
      if [ "$SMALLER" = "$VERSION_ARG" ] && [ "$VERSION_ARG" != "$BASE" ]; then
        echo "Versão $VERSION_ARG é menor que a atual ($BASE) — use uma versão maior ou igual (igual é permitido pra reexecução idempotente)." >&2
        exit 1
      fi
    fi
    NEW="${VERSION_ARG:-$BASE}"
    ;;
  patch|minor|major)
    if [[ "$CURRENT" == *-rc.* ]]; then
      # Já em RC (o bump de base já foi aplicado ao sair da versão estável): só incrementa o rc.
      RC_N="${CURRENT##*-rc.}"
      NEW="$BASE-rc.$((RC_N+1))"
    else
      # Versão estável: calcula a próxima X.Y.Z e entra em RC a partir de .1.
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
