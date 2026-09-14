#!/usr/bin/env bash
# bump-version.sh <patch|minor|major|release|current|files> [versão]
#
# Lê e grava a versão do projeto nos arquivos de versão configurados abaixo.
# Imprime só a versão resultante no stdout — capture com NEW_VERSION=$(bump-version.sh patch).
set -euo pipefail

# Arquivos que carregam a versão do projeto — preenchido por /setup.
VERSION_FILES=(
  # [DEFINIR: um caminho por linha, entre aspas — todo arquivo do projeto que carrega a versao]
)

ACTION="${1:-}"
VERSION_ARG="${2:-}"
[ -n "$ACTION" ] || { echo "Uso: bump-version.sh <patch|minor|major|release|current|files> [versão]" >&2; exit 1; }
[ "${#VERSION_FILES[@]}" -gt 0 ] || { echo "VERSION_FILES não configurado — rode /setup" >&2; exit 1; }
if [ -n "$VERSION_ARG" ] && [ "$ACTION" != "release" ]; then
  echo "[versão] só é aceito com a ação 'release' — para incrementar, rode bump-version.sh $ACTION sem a versão" >&2
  exit 1
fi
if [ -n "$VERSION_ARG" ] && ! [[ "$VERSION_ARG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versão inválida: $VERSION_ARG (use X.Y.Z, ex: 2.5.0)" >&2
  exit 1
fi

# Dono único da lista: quem precisa saber quais arquivos carregam versão pergunta
# aqui, em vez de manter uma segunda cópia que sai de sincronia com o /setup.
if [ "$ACTION" = "files" ]; then
  printf '%s
' "${VERSION_FILES[@]}"
  exit 0
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

# O `0,/re/s//` troca só a primeira ocorrência: a versão do próprio projeto vem
# antes das dependências.
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

# `|| true` para arquivo de versão ilegível virar a mensagem abaixo, não morte silenciosa.
CURRENT="$(read_version "${VERSION_FILES[0]}" || true)"
if ! [[ "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "Versão não lida de ${VERSION_FILES[0]} (valor: '${CURRENT:-vazio}') — confira o arquivo e a lista VERSION_FILES em bump-version.sh (preenchida pelo /setup)" >&2
  exit 1
fi

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
    # Remove o sufixo -rc.N; com [versão], grava essa em vez de derivar da atual.
    if [ -n "$VERSION_ARG" ]; then
      # Rejeita versão menor que a atual (tag pública regressiva); igual passa,
      # para não quebrar reexecução.
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
      # Normalmente só o -rc.N avança, porque a base subiu na entrada do ciclo; pedir mais
      # do que ele comporta sobe a base e reinicia o contador (nenhum -rc.N virou tag pública).
      SOBE=""
      case "$ACTION" in
        major) [ "$MINOR.$PATCH" = "0.0" ] || SOBE="$((MAJOR+1)).0.0" ;;
        minor) [ "$PATCH" = "0" ]          || SOBE="$MAJOR.$((MINOR+1)).0" ;;
      esac
      if [ -n "$SOBE" ]; then
        echo "ℹ️ Bump $ACTION num ciclo aberto em $CURRENT: a base subiu de $BASE para $SOBE e o contador de RC recomeçou em 1 — o corpo do CHANGELOG do ciclo continua valendo." >&2
        NEW="$SOBE-rc.1"
      else
        RC_N="${CURRENT##*-rc.}"
        NEW="$BASE-rc.$((RC_N+1))"
      fi
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
    echo "Ação inválida: $ACTION (use patch|minor|major|release|current|files)" >&2
    exit 1
    ;;
esac

for f in "${VERSION_FILES[@]}"; do
  write_version "$f" "$NEW"
done

echo "$NEW"
