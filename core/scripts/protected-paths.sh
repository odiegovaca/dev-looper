#!/usr/bin/env bash
# protected-paths.sh
#
# Imprime os globs dos Arquivos Protegidos, um por linha — só /dl-setup e /dl-lesson
# podem alterá-los (regra em AGENTS.md).
set -euo pipefail

{{PROMPTS_PROTECTED_ECHO}}
echo 'AGENTS.md'
