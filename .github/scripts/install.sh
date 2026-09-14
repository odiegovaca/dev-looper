#!/usr/bin/env bash
# install.sh <caminho-do-projeto> [--force]
#
# Instala os arquivos do dev-looper (.github/) num projeto de destino sem
# sobrescrever customizações locais: por arquivo, se o destino já existe e
# difere do que está sendo instalado, pula e reporta. Só sobrescreve com
# --force, que devolve os scripts configurados aos placeholders [DEFINIR] e
# obriga a rodar /setup de novo.
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

# Sem esta checagem, um caminho com typo virava uma árvore .github/ nova num
# diretório vazio e o script terminava dizendo "Instalados: N".
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

  # O /setup gera o copilot-instructions.md a partir do template e apaga o
  # template. Sem esta guarda, o destino "não tem" o arquivo e o install.sh o
  # recria, devolvendo ao projeto uma semente que ele já consumiu.
  if [ "$rel" = "copilot-instructions.template.md" ] && [ -f "$DEST_GITHUB/copilot-instructions.md" ]; then
    continue
  fi

  # O guia dos comandos carrega a versão de origem da instalação. A
  # substituição acontece antes da comparação, e não depois da cópia, para o
  # arquivo instalado ser idêntico ao que este script produziria de novo —
  # senão toda reexecução o apontaria como divergente.
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

# O `cp` propaga o modo da origem, e no Windows (core.filemode=false) todo
# script nasce 100644. Os prompts chamam os scripts direto, sem `bash`, e um
# script chama o outro igual — sem este chmod a chamada morre em Linux/macOS.
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

# O chmod acima vale para a arvore, nao para o que sera commitado: com
# core.filemode=false o git grava 100644 apesar dele. Corrigir exigiria mexer no
# indice do destino, que pode ter trabalho ja staged — entao so se avisa.
if [ "$(git -C "$DEST" config --get core.filemode 2>/dev/null || true)" = "false" ]; then
  echo ""
  echo "Aviso: este repositório está com core.filemode=false — o bit de execução"
  echo "dos scripts não sobrevive ao commit. No diretório do projeto, antes de"
  echo "commitar, rode (o add é necessário: update-index só aceita rastreado):"
  echo "  git add .github/scripts && git update-index --chmod=+x .github/scripts/*.sh"
fi
