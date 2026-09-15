#!/usr/bin/env bash
# install.sh <caminho-do-projeto> [--force]
#
# Instala o .github/ do dev-looper num projeto: arquivo que já existe e difere é
# pulado e reportado. --force sobrescreve, devolvendo os scripts aos [DEFINIR].
set -euo pipefail

DEST=""
FORCE=false
TEMPLATE_PULADO=false
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

# Destino tem de existir: um typo criaria uma árvore .github/ nova e o script diria "Instalados: N".
if [ ! -d "$DEST" ]; then
  echo "Destino não encontrado: $DEST — confira o caminho (ou crie o diretório do projeto) antes de instalar" >&2
  exit 1
fi

# Aviso, não erro: o /setup ainda roda num diretório que não é repo, mas todo o
# fluxo depois dele (branches, diff, merge-base, PR) precisa de git.
if ! git -C "$DEST" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Aviso: $DEST não é um repositório git — rode 'git init' lá antes do /setup." >&2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/../.." && pwd)/.github"
DEST_GITHUB="$DEST/.github"

# De qual versão do dev-looper este projeto vai partir. Vazio quando a origem
# não é um clone git com tags (download de zip, por exemplo).
VERSION="$(git -C "$(dirname "$SRC")" describe --tags --dirty 2>/dev/null || true)"

RENDERED="$(mktemp)"
trap 'rm -f "$RENDERED"' EXIT

mkdir -p "$DEST_GITHUB"

COPIED=()
SKIPPED=()

while IFS= read -r -d '' file; do
  rel="${file#"$SRC"/}"
  dest_file="$DEST_GITHUB/$rel"

  # O /setup consome o template e o apaga: sem esta guarda, o install.sh devolveria
  # ao projeto uma semente que ele já usou.
  if [ "$rel" = "copilot-instructions.template.md" ] && [ -f "$DEST_GITHUB/copilot-instructions.md" ]; then
    TEMPLATE_PULADO=true
    continue
  fi

  # A versão entra antes da comparação, não depois da cópia, senão toda reexecução
  # apontaria o arquivo instalado como divergente.
  src_file="$file"
  if [ "$rel" = "prompts/README.md" ]; then
    sed "s|__DEV_LOOPER_VERSION__|${VERSION:-desconhecida}|" "$file" > "$RENDERED"
    src_file="$RENDERED"
  fi

  mkdir -p "$(dirname "$dest_file")"

  if [ -f "$dest_file" ]; then
    if cmp -s "$src_file" "$dest_file"; then
      continue
    fi
    if [ "$FORCE" = true ]; then
      cp "$src_file" "$dest_file"
      COPIED+=("$rel (sobrescrito)")
    else
      SKIPPED+=("$rel")
    fi
  else
    cp "$src_file" "$dest_file"
    COPIED+=("$rel")
  fi
done < <(find "$SRC" -type f -print0)

# Prompts e scripts se chamam direto, sem `bash`: sem o bit de execução a chamada
# morre em Linux/macOS, e o `cp` traz 100644 de um Windows com core.filemode=false.
find "$DEST_GITHUB" -type f -name '*.sh' -exec chmod +x {} +

echo "Instalados/atualizados: ${#COPIED[@]}"
if [ "${#COPIED[@]}" -gt 0 ]; then
  printf '  %s\n' "${COPIED[@]}"
fi

if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo ""
  echo "Pulados (já existem e diferem do que está sendo instalado — use --force para sobrescrever): ${#SKIPPED[@]}"
  printf '  %s\n' "${SKIPPED[@]}"
fi

echo ""
if [ -n "$VERSION" ]; then
  echo "Versão de origem: $VERSION — registrada em .github/prompts/README.md"
else
  echo "Versão de origem: desconhecida (a origem não é um clone git com tags)"
fi

if [ "$TEMPLATE_PULADO" = true ]; then
  echo ""
  echo "Nota: o copilot-instructions.template.md foi pulado porque este projeto já tem o"
  echo "copilot-instructions.md preenchido. Se o template mudou nesta versão, ele não chega"
  echo "sozinho: rode /setup de novo para reescrever as instruções a partir do template novo."
fi

# O chmod acima não alcança o que será commitado, e consertar exigiria mexer no
# índice do destino, que pode ter trabalho staged — então só avisa.
if [ "$(git -C "$DEST" config --get core.filemode 2>/dev/null || true)" = "false" ]; then
  echo ""
  echo "Aviso: este repositório está com core.filemode=false — o bit de execução"
  echo "dos scripts não sobrevive ao commit. No diretório do projeto, antes de"
  echo "commitar, rode (o add é necessário: update-index só aceita rastreado):"
  echo "  git add .github/scripts && git update-index --chmod=+x .github/scripts/*.sh"
fi
