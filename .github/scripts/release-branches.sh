#!/usr/bin/env bash
# release-branches.sh
#
# Imprime PROD_BRANCH e INTEGRATION_BRANCH (uma var por linha, formato
# KEY=value — usar com `eval "$(release-branches.sh)"`). Centralizado aqui
# para /code, /rc e /release não reparsearem a mesma prosa a cada execução.
set -euo pipefail

# Preenchidos por /setup a partir da seção Release Workflow do
# copilot-instructions.md.
PROD_BRANCH="[DEFINIR: ex. main]"
INTEGRATION_BRANCH="[DEFINIR: ex. develop]"

if [[ "$PROD_BRANCH" == "[DEFINIR"* || "$INTEGRATION_BRANCH" == "[DEFINIR"* ]]; then
  echo "PROD_BRANCH/INTEGRATION_BRANCH não configurados — rode /setup" >&2
  exit 1
fi

# Avisa (stderr, não bloqueia) se origin/$PROD_BRANCH tem commits que
# origin/$INTEGRATION_BRANCH ainda não tem — sinal de que o passo 6 do
# /release (release-postmerge.sh) ficou pendente, ou que houve hotfix direto
# em produção. Como isto roda no início de todo /code, /rc e /release, é o
# ponto único onde esse esquecimento aparece antes de virar um problema
# maior (ex: /rc calculando a próxima versão a partir de uma base
# desatualizada). Usa só o estado local dos refs remotos (sem `git fetch`),
# pra não adicionar latência de rede a cada comando — pode não pegar um
# release mergeado há poucos segundos.
if git rev-parse --verify -q "origin/$PROD_BRANCH" >/dev/null && git rev-parse --verify -q "origin/$INTEGRATION_BRANCH" >/dev/null; then
  if ! git merge-base --is-ancestor "origin/$PROD_BRANCH" "origin/$INTEGRATION_BRANCH" 2>/dev/null; then
    echo "⚠️ origin/$PROD_BRANCH tem commits que origin/$INTEGRATION_BRANCH não tem — se um release foi mergeado recentemente, rode .github/scripts/release-postmerge.sh (passo 6 do /release)." >&2
  fi
fi

echo "PROD_BRANCH=$PROD_BRANCH"
echo "INTEGRATION_BRANCH=$INTEGRATION_BRANCH"
