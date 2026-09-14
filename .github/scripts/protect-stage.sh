#!/usr/bin/env bash
# protect-stage.sh
#
# Remove do stage git qualquer mudança em Arquivos Protegidos (regra em
# copilot-instructions.md — só /setup e /lesson podem alterá-los). Rodar
# logo depois de um `git add .` que antecede um commit automático, sem
# pausa pro agente conferir o stage — usado por /rc e /release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Glob entre aspas de propósito: quem casa é o git, contra o índice e o HEAD,
# não o shell contra a árvore de trabalho. A diferença aparece na deleção de um
# arquivo protegido — a expansão do shell não produz caminho que não existe
# mais, e a deleção seguia staged para o commit automático do /rc e do /release.
while IFS= read -r glob; do
  [ -n "$glob" ] || continue
  git restore --staged -- "$glob" 2>/dev/null || true
done < <("$SCRIPT_DIR/protected-paths.sh")
