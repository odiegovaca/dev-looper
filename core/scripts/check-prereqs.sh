#!/usr/bin/env bash
# check-prereqs.sh
#
# Confere o que o fluxo precisa antes do /setup: `gh` instalado e autenticado.
# Falha com exit 1 e a correção na própria mensagem; a resolução de repositório do
# gh sai só como aviso, porque os scripts passam --repo e não dependem dela.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI não encontrado — instale antes de continuar: https://cli.github.com" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh CLI não autenticado — rode: gh auth login" >&2
  exit 1
fi

ORIGIN_REPO="$("$SCRIPT_DIR/gh-repo.sh")"
GH_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"

echo "Pré-requisitos OK: gh instalado e autenticado."
echo "   Remoto origin: $ORIGIN_REPO"

# Aviso e não erro: os scripts do fluxo passam --repo e não dependem desta
# resolução; quem digitar um `gh` à mão, sim — e num fork ele escolhe o upstream.
if [ "$GH_REPO" != "$ORIGIN_REPO" ]; then
  echo "   ⚠️ gh por conta própria resolve para ${GH_REPO:-nada} — um gh digitado à mão não escreveria em $ORIGIN_REPO. Rode: gh repo set-default $ORIGIN_REPO" >&2
fi
