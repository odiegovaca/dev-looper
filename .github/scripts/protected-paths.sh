#!/usr/bin/env bash
# protected-paths.sh
#
# Imprime os globs dos Arquivos Protegidos, um por linha — só /setup e /lesson
# podem alterá-los (regra em copilot-instructions.md).
set -euo pipefail

echo '.github/prompts/*.md'
echo '.github/copilot-instructions.md'
