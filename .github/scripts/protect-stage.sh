#!/usr/bin/env bash
# protect-stage.sh
#
# Remove do stage qualquer mudança em Arquivos Protegidos. Rodar logo depois
# de um `git add .` que antecede um commit automático.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Glob entre aspas: quem casa é o git contra o índice, não o shell contra a
# árvore — a expansão do shell não alcança um arquivo protegido que foi deletado.
while IFS= read -r glob; do
  [ -n "$glob" ] || continue
  git restore --staged -- "$glob" 2>/dev/null || true
done < <("$SCRIPT_DIR/protected-paths.sh")
