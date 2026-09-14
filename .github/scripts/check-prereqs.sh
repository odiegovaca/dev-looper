#!/usr/bin/env bash
# check-prereqs.sh
#
# Confere o que o fluxo precisa antes do /setup: `gh` instalado e autenticado.
# Falha com exit 1 e a correção na própria mensagem.
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI não encontrado — instale antes de continuar: https://cli.github.com" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh CLI não autenticado — rode: gh auth login" >&2
  exit 1
fi

echo "Pré-requisitos OK: gh instalado e autenticado."
