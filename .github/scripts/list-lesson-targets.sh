#!/usr/bin/env bash
# list-lesson-targets.sh
#
# Lista os destinos elegíveis para /lesson: cada .github/prompts/*.prompt.md
# com sua description (frontmatter) como sinal de classificação, mais
# copilot-instructions.md e README.md (destinos fixos, sem frontmatter).
# Reflete o estado real do .github/ na execução — nenhum prompt novo,
# removido ou renomeado passa batido, como passaria com uma lista mantida
# manualmente.
set -euo pipefail

for f in .github/prompts/*.prompt.md; do
  DESC="$(grep -m1 '^description:' "$f" | sed -E 's/^description:\s*//')"
  echo "$f: $DESC"
done

echo ".github/copilot-instructions.md: Convenções e padrões específicos deste projeto"
echo ".github/prompts/README.md: Documentação do fluxo geral de prompts"
