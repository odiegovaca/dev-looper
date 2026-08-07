#!/usr/bin/env bash
# rc-prepare.sh [tipo]
#
# Resolve tudo que o passo 1 do /rc precisa antes da decisão de TIPO.
# Orquestra release-branches.sh/feature-number.sh/changed-files.sh — os três
# continuam chamáveis direto por /code, /review, /fix-review e /release;
# este script só existe para a sequência específica do /rc.
#
# Imprime INTEGRATION_BRANCH/FEATURE_N/TIPO (uma var por linha, formato
# KEY=value — TIPO fica vazio se ainda não decidido), seguido de
# "CHANGED_FILES:" e a lista de arquivos alterados, um por linha (mesmo
# formato do "DIFF:" em review-prepare.sh). PROD_BRANCH e CURRENT_BRANCH só
# servem pra checagem de branch protegida abaixo — não são consumidos por
# nenhum passo depois, por isso não saem no output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TIPO_ARG="${1:-}"
case "$TIPO_ARG" in
  patch|minor|major|"") ;;
  *) echo "Argumento inválido: $TIPO_ARG (use patch, minor ou major)" >&2; exit 1 ;;
esac

eval "$("$SCRIPT_DIR/release-branches.sh")"
CURRENT_BRANCH="$(git branch --show-current)"
# /rc empacota trabalho de feature — não faz sentido (e não deve ser possível)
# rodar de dentro da própria branch de produção ou integração.
if [ "$CURRENT_BRANCH" = "$PROD_BRANCH" ] || [ "$CURRENT_BRANCH" = "$INTEGRATION_BRANCH" ]; then
  echo "Branch protegida ($CURRENT_BRANCH) — troque para uma branch de feature/fix antes de rodar /rc." >&2
  exit 1
fi

FEATURE_N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"

# git add . + commit rodam atômicos aqui, sem pausa pro agente conferir o
# stage — por isso os Arquivos Protegidos (regra em copilot-instructions.md)
# são desestageados de forma determinística antes do commit, em vez de
# depender de o agente lembrar de checar.
git add .
"$SCRIPT_DIR/protect-stage.sh"
git diff --cached --quiet || git commit -m "chore: finalize feature implementation"

CHANGED_FILES="$("$SCRIPT_DIR/changed-files.sh" "$INTEGRATION_BRANCH")"

echo "INTEGRATION_BRANCH=$INTEGRATION_BRANCH"
echo "FEATURE_N=$FEATURE_N"
echo "TIPO=$TIPO_ARG"
echo "CHANGED_FILES:"
echo "$CHANGED_FILES"
