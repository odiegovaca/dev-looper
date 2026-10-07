#!/usr/bin/env bash
# list-lesson-targets.sh
#
# Lista os destinos elegíveis para /dl-lesson: cada {{PROMPTS_DIR}}/*{{PROMPT_EXT}} com
# sua description, mais {{INSTRUCTIONS}} e README.md (destinos fixos).
# Derivado do .github/ na execução, para prompt novo ou renomeado não passar batido.
set -euo pipefail

# `|| true` para prompt sem `description:` não derrubar a lista.
for f in {{PROMPTS_DIR}}/*{{PROMPT_EXT}}; do
  DESC="$(grep -m1 '^description:' "$f" | sed -E 's/^description:\s*//' || true)"
  echo "$f: ${DESC:-[sem description no frontmatter]}"
done

echo "{{INSTRUCTIONS_PATH}}: Convenções e padrões específicos deste projeto"
echo "{{GUIDE_PATH}}: Documentação do fluxo geral de prompts"
