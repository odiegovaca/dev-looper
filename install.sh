#!/usr/bin/env bash
# install.sh <caminho-do-projeto> [--agent copilot|claude] [--force]
#
# Instala o dev-looper num projeto, no layout do agente escolhido (padrão: copilot).
# O conteúdo vem de core/ e passa pelo adaptador em adapters/<agente>.sh, que dá o
# destino de cada arquivo, o frontmatter dos prompts e o valor de cada {{MARCADOR}}.
# Arquivo que já existe e difere é pulado e reportado. --force sobrescreve,
# devolvendo os scripts aos [DEFINIR].
set -euo pipefail

DEST=""
AGENT="copilot"
FORCE=false
TEMPLATE_PULADO=false
USO="Uso: install.sh <caminho-do-projeto> [--agent copilot|claude] [--force]"
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=true ;;
    --agent)
      [ $# -ge 2 ] || { echo "$USO" >&2; exit 1; }
      AGENT="$2"
      shift
      ;;
    --agent=*) AGENT="${1#--agent=}" ;;
    *) DEST="$1" ;;
  esac
  shift
done

if [ -z "$DEST" ]; then
  echo "$USO" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$ROOT/core"
ADAPTER="$ROOT/adapters/$AGENT.sh"

if [ ! -f "$ADAPTER" ]; then
  echo "Agente desconhecido: $AGENT — use copilot ou claude" >&2
  exit 1
fi

# Destino tem de existir: um typo criaria uma árvore nova e o script diria "Instalados: N".
if [ ! -d "$DEST" ]; then
  echo "Destino não encontrado: $DEST — confira o caminho (ou crie o diretório do projeto) antes de instalar" >&2
  exit 1
fi

# Aviso, não erro: o /setup ainda roda num diretório que não é repo, mas todo o
# fluxo depois dele (branches, diff, merge-base, PR) precisa de git.
if ! git -C "$DEST" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Aviso: $DEST não é um repositório git — rode 'git init' lá antes do /setup." >&2
fi

EXTRAS=()
# shellcheck source=/dev/null
source "$ADAPTER"

# De qual versão do dev-looper este projeto vai partir. Vazio quando a origem
# não é um clone git com tags (download de zip, por exemplo).
VERSION="$(git -C "$ROOT" describe --tags --dirty 2>/dev/null || true)"
export DL_VERSION="${VERSION:-desconhecida}"

# Todo DL_* exportado (adaptador + versão) é um marcador {{...}}.
CHAVES="$(compgen -e | sed -n 's/^DL_//p' | tr '\n' ' ')"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RENDERED="$TMP/rendered"

# render <arquivo> — grava em $RENDERED o arquivo com frontmatter de prompt
# adaptado e marcadores trocados. Troca literal (index, não regex): os valores
# têm `*`, `.` e crase.
render() {
  local src="$1" fim
  if [[ "$src" == "$CORE/prompts/"* ]]; then
    fim="$(awk 'NR > 1 && /^---$/ { print NR; exit }' "$src")"
    if [ -z "$fim" ] || [ "$(head -1 "$src")" != "---" ]; then
      echo "Prompt sem frontmatter: $src" >&2
      exit 1
    fi
    {
      echo '---'
      sed -n "2,$((fim - 1))p" "$src" | frontmatter
      echo '---'
      tail -n +"$((fim + 1))" "$src"
    } > "$TMP/fm"
    src="$TMP/fm"
  fi

  awk -v chaves="$CHAVES" '
    BEGIN { n = split(chaves, k, " ") }
    {
      linha = $0
      for (i = 1; i <= n; i++) {
        alvo = "{{" k[i] "}}"; valor = ENVIRON["DL_" k[i]]; saida = ""
        while ((p = index(linha, alvo)) > 0) {
          saida = saida substr(linha, 1, p - 1) valor
          linha = substr(linha, p + length(alvo))
        }
        linha = saida linha
      }
      print linha
    }' "$src" > "$RENDERED"

  # Marcador que sobrou é valor que falta no adaptador: instalar assim deixaria
  # um {{...}} no meio de um prompt.
  if grep -n '{{[A-Z_]*}}' "$RENDERED" >&2; then
    echo "Marcador sem valor em adapters/$AGENT.sh, no arquivo ${1#"$ROOT"/}" >&2
    exit 1
  fi
}

COPIED=()
SKIPPED=()

# instalar <origem> <destino-relativo> [so-se-ausente]
instalar() {
  local rel="$2" dest_file="$DEST/$2"
  render "$1"
  mkdir -p "$(dirname "$dest_file")"

  if [ -f "$dest_file" ]; then
    if cmp -s "$RENDERED" "$dest_file" || [ "${3:-}" = so-se-ausente ]; then
      return
    fi
    if [ "$FORCE" = true ]; then
      cp "$RENDERED" "$dest_file"
      COPIED+=("$rel (sobrescrito)")
    else
      SKIPPED+=("$rel")
    fi
  else
    cp "$RENDERED" "$dest_file"
    COPIED+=("$rel")
  fi
}

while IFS= read -r -d '' file; do
  rel="$(destino "${file#"$CORE"/}")"
  [ -n "$rel" ] || continue

  # O /setup consome o template e o apaga: sem esta guarda, o install.sh devolveria
  # ao projeto uma semente que ele já usou.
  if [ "$rel" = "$DL_INSTRUCTIONS_TEMPLATE_PATH" ] && [ -f "$DEST/$DL_INSTRUCTIONS_PATH" ]; then
    TEMPLATE_PULADO=true
    continue
  fi

  instalar "$file" "$rel"
done < <(find "$CORE" -type f -print0 | sort -z)

# Extras do adaptador são do projeto depois de criados (o CLAUDE.md, por exemplo):
# nem --force os sobrescreve.
for extra in ${EXTRAS[@]+"${EXTRAS[@]}"}; do
  instalar "$ROOT/adapters/$AGENT/$extra" "$extra" so-se-ausente
done

# Prompts e scripts se chamam direto, sem `bash`: sem o bit de execução a chamada
# morre em Linux/macOS, e o `cp` traz 100644 de um Windows com core.filemode=false.
find "$DEST/.github" -type f -name '*.sh' -exec chmod +x {} +

echo "Agente: $AGENT"
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
  echo "Versão de origem: $VERSION — registrada em $DL_GUIDE_PATH"
else
  echo "Versão de origem: desconhecida (a origem não é um clone git com tags)"
fi

if [ "$TEMPLATE_PULADO" = true ]; then
  echo ""
  echo "Nota: o $DL_INSTRUCTIONS_TEMPLATE foi pulado porque este projeto já tem o"
  echo "$DL_INSTRUCTIONS preenchido. Se o template mudou nesta versão, ele não chega"
  echo "sozinho: rode /setup de novo para reescrever as instruções a partir do template novo."
fi

if declare -F notas >/dev/null; then
  notas
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
