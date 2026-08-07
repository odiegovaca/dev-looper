#!/usr/bin/env bash
# protect-stage.sh
#
# Remove do stage git qualquer mudança em Arquivos Protegidos (regra em
# copilot-instructions.md — só /setup e /lesson podem alterá-los). Rodar
# logo depois de um `git add .` que antecede um commit automático, sem
# pausa pro agente conferir o stage — usado por /rc e /release.
set -euo pipefail

git restore --staged .github/prompts/*.md .github/copilot-instructions.md 2>/dev/null || true
