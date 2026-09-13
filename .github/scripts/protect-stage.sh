#!/usr/bin/env bash
# protect-stage.sh
#
# Remove do stage git qualquer mudança em Arquivos Protegidos (regra em
# copilot-instructions.md — só /setup e /lesson podem alterá-los). Rodar
# logo depois de um `git add .` que antecede um commit automático, sem
# pausa pro agente conferir o stage — usado por /rc e /release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Globs vindos do protected-paths.sh, deliberadamente sem aspas: é a expansão
# que transforma cada glob nos caminhos que o git restore recebe.
while IFS= read -r glob; do
  [ -n "$glob" ] || continue
  git restore --staged $glob 2>/dev/null || true
done < <("$SCRIPT_DIR/protected-paths.sh")
