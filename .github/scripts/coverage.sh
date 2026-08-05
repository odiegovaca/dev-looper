#!/usr/bin/env bash
# coverage.sh — imprime só o número da cobertura de statements do relatório já
# gerado (sem rodar os testes de novo). Exit 1 silencioso se o relatório não existir.
#
# O corpo de read_coverage() é preenchido por /setup com o comando do stack
# detectado no Step 1 (mesma tabela que hoje vai para copilot-instructions.md
# → "Coverage Report").
set -euo pipefail

read_coverage() {
  # [DEFINIR: comando por stack, ex:]
  # Node.js/Jest: cat coverage/coverage-summary.json | node -e "const j=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(j.total.statements.pct)"
  # Java/JaCoCo:  awk -F',' 'NR>1{c+=$4;t+=$3+$4}END{printf "%.1f\n",c/t*100}' target/site/jacoco/jacoco.csv
  # Python:       coverage report --format=total
  # Go:           go tool cover -func=coverage.out | grep total | awk '{print $3}' | tr -d '%'
  return 1
}

read_coverage 2>/dev/null || exit 1
