#!/usr/bin/env bash
# list-lesson-targets.sh
#
# Lista os destinos elegíveis para /lesson: cada .github/prompts/*.prompt.md com
# sua description, mais copilot-instructions.md e README.md (destinos fixos).
# Derivado do .github/ na execução, para prompt novo ou renomeado não passar batido.
set -euo pipefail

# `|| true` para prompt sem `description:` não derrubar a lista.
for f in .github/prompts/*.prompt.md; do
  DESC="$(grep -m1 '^description:' "$f" | sed -E 's/^description:\s*//' || true)"
  echo "$f: ${DESC:-[sem description no frontmatter]}"
done

echo ".github/copilot-instructions.md: Convenções e padrões específicos deste projeto"
echo ".github/prompts/README.md: Documentação do fluxo geral de prompts"
