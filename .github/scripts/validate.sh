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

run_test() {
  # [DEFINIR: ex. npm test | mvn test | go test ./... | pytest]
  echo "run_test não configurado — rode /setup" >&2
  exit 1
}

run_lint() {
  # [DEFINIR: ex. npm run lint | mvn checkstyle:check | golangci-lint run | ruff check .]
  echo "run_lint não configurado — rode /setup" >&2
  exit 1
}

run_build() {
  # [DEFINIR: ex. npm run build | mvn package | go build ./... | docker build .]
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
