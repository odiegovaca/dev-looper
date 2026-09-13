#!/usr/bin/env bash
# validate.sh <ação> [ação...]
#
# Executa o(s) comando(s) de validação do stack para as ações pedidas, na
# ordem informada, parando na primeira que falhar (herda o set -e abaixo).
# Corpo de cada função é preenchido por /setup com os comandos reais de
# Development Commands (mesma fonte que hoje vai para copilot-instructions.md).
# Usado por /code, /test, /rc e /fix-review — todos rodam test/lint/build em
# algum ponto do fluxo, alguns combinando mais de uma ação numa chamada só
# (ex: `validate.sh lint build`) para não precisar de uma linha por ação.
set -euo pipefail

# Contrato com o coverage.sh: este comando precisa GERAR o relatorio apontado em
# COVERAGE_REPORT — o coverage.sh so le o que ja esta no disco. Sem isso nada
# falha: o relatorio congela e o /test prioriza gaps ja cobertos e declara meta
# atingida em cima de numero velho. Onde a cobertura sai de uma fase separada
# (ex: JaCoCo no `verify`), e essa fase que vai aqui, nao o `test` puro.
run_test() {
  # [DEFINIR: comando de teste do projeto, gerando o relatorio de COVERAGE_REPORT]
  echo "run_test não configurado — rode /setup" >&2
  exit 1
}

run_lint() {
  # [DEFINIR: comando de lint do projeto]
  echo "run_lint não configurado — rode /setup" >&2
  exit 1
}

run_build() {
  # [DEFINIR: comando de build do projeto]
  echo "run_build não configurado — rode /setup" >&2
  exit 1
}

if [ "$#" -eq 0 ]; then
  echo "Uso: validate.sh <test|lint|build> [test|lint|build...]" >&2
  exit 1
fi

for ACTION in "$@"; do
  case "$ACTION" in
    test)  run_test ;;
    lint)  run_lint ;;
    build) run_build ;;
    *) echo "Ação inválida: $ACTION (use test, lint ou build)" >&2; exit 1 ;;
  esac
done
