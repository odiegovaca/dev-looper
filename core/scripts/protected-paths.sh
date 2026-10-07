#!/usr/bin/env bash
# protected-paths.sh
#
# Imprime os globs dos Arquivos Protegidos, um por linha — só /setup e /lesson
# podem alterá-los (regra em {{INSTRUCTIONS}}).
set -euo pipefail

{{PROMPTS_PROTECTED_ECHO}}
echo '{{INSTRUCTIONS_PATH}}'
