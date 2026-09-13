#!/usr/bin/env bash
# protected-paths.sh
#
# Imprime, um por linha, os globs dos Arquivos Protegidos — os que só /setup e
# /lesson podem alterar (regra em copilot-instructions.md). Centralizado aqui
# para protect-stage.sh e fix-review-finalize.sh não manterem a mesma lista
# cada um por si: a lista é um contrato do workflow, e contrato duplicado é o
# que sai de sincronia.
set -euo pipefail

echo '.github/prompts/*.md'
echo '.github/copilot-instructions.md'
