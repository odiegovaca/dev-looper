#!/usr/bin/env bash
# bump-version.sh <patch|minor|major|release|current|files> [versão]
#
# Lê e grava a versão do projeto nos arquivos de versão configurados abaixo.
# Imprime só a versão resultante no stdout — capture com NEW_VERSION=$(bump-version.sh patch).
set -euo pipefail

# Arquivos que carregam a versão do projeto — preenchido por /setup.
VERSION_FILES=(
  # [DEFINIR: um caminho por linha, entre aspas — todo arquivo que carrega a versao do
  # projeto, incluido o lockfile quando ele a repete]
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

# Como o projeto grava a versão, antes do write_version() porque acertar todos os
# lugares em que ela aparece é conhecimento do projeto, não do dev-looper.
SET_VERSION_CMD="[DEFINIR: comando que grava a versao do projeto, {} no lugar do numero, ou - se nao houver ferramenta propria]"

# Fallback de quem não tem ferramenta própria. O `0,/re/s//` troca só a primeira
# ocorrência: a versão do projeto vem antes das dependências.
write_version() {
  local file="$1" new="$2"
  case "$file" in
    *.json)
      # Um lockfile repete a versão do projeto no pacote raiz de `packages`, a chave `""`:
      # trocar só a primeira deixaria o `npm ci` recusando o lock.
      awk -v novo="$new" '
        function troca() { sub(/"version"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"version\": \"" novo "\"") }
        !raiz && /"version"[[:space:]]*:/          { troca(); raiz = 1; print; next }
        /^[[:space:]]*"":[[:space:]]*\{/           { pacote_raiz = 1; print; next }
        pacote_raiz && /"version"[[:space:]]*:/    { troca(); pacote_raiz = 0; print; next }
        # Qualquer outra chave de objeto encerra o pacote raiz: daqui para baixo toda
        # versão é de dependência.
        /^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*\{/ { pacote_raiz = 0 }
        { print }
      ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
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

# HEAD e tags: a ferramenta do projeto não pode mexer em nenhum dos dois.
git_estado() { git rev-parse HEAD 2>/dev/null || true; git tag 2>/dev/null || true; }

if [ "$SET_VERSION_CMD" = "-" ] || [[ "$SET_VERSION_CMD" == "[DEFINIR"* ]]; then
  for f in "${VERSION_FILES[@]}"; do
    write_version "$f" "$NEW"
  done
else
  # Sem `if` em volta: o `set -e` mata o script se a ferramenta falhar, em vez de a
  # falha dela virar edição na mão pelo write_version().
  ANTES="$(git_estado)"
  # `>&2` porque o stdout daqui é só a versão, e toda ferramenta anuncia o que fez.
  eval "${SET_VERSION_CMD//\{\}/$NEW}" >&2
  if [ "$(git_estado)" != "$ANTES" ]; then
    echo "O comando de SET_VERSION_CMD commitou ou criou tag, e não pode: quem commita é o /rc, depois." >&2
    echo "   Ajuste o comando em bump-version.sh, preenchido pelo /setup." >&2
    exit 1
  fi
fi

# Lê de volta porque uma ferramenta chamada com a flag errada não falha, só não grava.
for f in "${VERSION_FILES[@]}"; do
  GRAVADA="$(read_version "$f" || true)"
  [ "$GRAVADA" = "$NEW" ] && continue
  echo "Versão não gravada em $f: continua em '${GRAVADA:-vazio}', esperado '$NEW'." >&2
  echo "   Confira SET_VERSION_CMD e VERSION_FILES em bump-version.sh, preenchidos pelo /setup." >&2
  echo "   A lista pode ter ficado meio gravada — confira os outros arquivos antes de rodar de novo." >&2
  exit 1
done

echo "$NEW"
