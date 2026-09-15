#!/usr/bin/env bash
# rc-prepare.sh [tipo]
#
# Resolve tudo que o passo 1 do /rc precisa antes da decisão de TIPO: valida a
# branch, commita o trabalho pendente e lista os arquivos alterados.
#
# Imprime INTEGRATION_BRANCH/FEATURE_N/TIPO em KEY=value (TIPO vazio se ainda
# não decidido), seguido de "CHANGED_FILES:" e a lista, um arquivo por linha.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TIPO_ARG="${1:-}"
case "$TIPO_ARG" in
  patch|minor|major|"") ;;
  *) echo "Argumento inválido: $TIPO_ARG (use patch, minor ou major)" >&2; exit 1 ;;
esac

eval "$("$SCRIPT_DIR/release-branches.sh")"
CURRENT_BRANCH="$(git branch --show-current)"
# /rc empacota trabalho de feature: não roda de dentro de produção nem da integração.
if [ "$CURRENT_BRANCH" = "$PROD_BRANCH" ] || [ "$CURRENT_BRANCH" = "$INTEGRATION_BRANCH" ]; then
  echo "Branch protegida ($CURRENT_BRANCH) — troque para uma branch de feature/fix antes de rodar /rc." >&2
  exit 1
fi
# Branch de release não é feature: aqui o PR sairia com a base errada e um -rc.N
# novo cairia sobre uma versão já fechada.
case "$CURRENT_BRANCH" in
  release/v*)
    echo "Branch de release ($CURRENT_BRANCH) — /rc abriria PR para $INTEGRATION_BRANCH, base errada." >&2
    echo "   Commite o ajuste aqui mesmo e rode /release ${CURRENT_BRANCH#release/v} de novo: o PR já aberto recebe o push." >&2
    exit 1
    ;;
esac

FEATURE_N="$("$SCRIPT_DIR/feature-number.sh" 2>/dev/null || true)"

# add + commit rodam atômicos aqui, então os Arquivos Protegidos saem do stage antes.
git add .
"$SCRIPT_DIR/protect-stage.sh"
git diff --cached --quiet || git commit -m "chore: finalize feature implementation"

CHANGED_FILES="$("$SCRIPT_DIR/changed-files.sh" "$INTEGRATION_BRANCH")"

echo "INTEGRATION_BRANCH=$INTEGRATION_BRANCH"
echo "FEATURE_N=$FEATURE_N"
echo "TIPO=$TIPO_ARG"
echo "CHANGED_FILES:"
echo "$CHANGED_FILES"
