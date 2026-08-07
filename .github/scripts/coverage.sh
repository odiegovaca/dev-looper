#!/usr/bin/env bash
# coverage.sh [--priority] — imprime a cobertura de statements do relatório já
# gerado (sem rodar os testes de novo). Exit 1 silencioso se o relatório não existir.
set -euo pipefail

# Preenchido por /setup com o comando do stack detectado no Passo 1 (mesma
# tabela que hoje vai para copilot-instructions.md → "Coverage Report").
# Sem argumento, coverage.sh imprime só o número total (%) — usado por
# /status e pela checagem de meta em /test.
read_coverage() {
  # [DEFINIR: comando por stack, ex:]
  # Node.js/Jest: cat coverage/coverage-summary.json | node -e "const j=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(j.total.statements.pct)"
  # Java/JaCoCo:  awk -F',' 'NR>1{c+=$4;t+=$3+$4}END{printf "%.1f\n",c/t*100}' target/site/jacoco/jacoco.csv
  # Python:       coverage report --format=total
  # Go:           go tool cover -func=coverage.out | grep total | awk '{print $3}' | tr -d '%'
  return 1
}

# Saída "arquivo,pct,total_statements" — insumo de --priority via
# rank_priority() abaixo. Usado por /test para priorizar onde escrever teste
# sem depender de cálculo manual.
read_coverage_by_file() {
  # [DEFINIR: comando por stack, ex:]
  # Node.js/Jest: cat coverage/coverage-summary.json | node -e "const j=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));Object.entries(j).filter(([f])=>f!=='total').forEach(([f,d])=>console.log(f+','+d.statements.pct+','+d.statements.total))"
  # Java/JaCoCo:  awk -F',' 'NR>1{printf "%s/%s,%.1f,%d\n",$2,$3,$5/($4+$5)*100,$4+$5}' target/site/jacoco/jacoco.csv
  # Python:       coverage json -o /dev/stdout | python3 -c "import json,sys; d=json.load(sys.stdin)['files']; [print(f'{f},{v[\"summary\"][\"percent_covered\"]:.1f},{v[\"summary\"][\"num_statements\"]}') for f,v in d.items()]"
  # Go:           go tool cover -func=coverage.out | grep -v ^total: | awk '{print $1","$3","}' | tr -d '%'  # 3ª coluna vazia — go tool cover não expõe total de statements por arquivo
  return 1
}

# Lê "arquivo,pct,total_statements" do stdin, imprime "arquivo,rank_sum"
# ordenado por prioridade (menor rank_sum primeiro).
rank_priority() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  cat > "$tmp/data.csv"
  [[ -s "$tmp/data.csv" ]] || return 0

  # Sem total_statements em nenhuma linha: cai para ordenar só por pct.
  if ! awk -F, 'NF>=3 && $3!="" {found=1} END{exit !found}' "$tmp/data.csv"; then
    sort -t, -k2,2n "$tmp/data.csv" | awk -F, '{print $1",-"}'
    return 0
  fi

  # Rank A: posição por pct crescente (pior cobertura relativa primeiro).
  sort -t, -k2,2n "$tmp/data.csv" \
    | awk -F, '{print $1","NR}' \
    | sort -t, -k1,1 > "$tmp/rankA.csv"

  # Rank B: posição por statements não cobertos decrescente (maior ganho absoluto primeiro).
  awk -F, '{printf "%.4f,%s\n", $3*(100-$2)/100, $1}' "$tmp/data.csv" \
    | sort -t, -k1,1 -rn \
    | awk -F, '{print $2","NR}' \
    | sort -t, -k1,1 > "$tmp/rankB.csv"

  # Prioridade = soma das duas posições de rank, menor primeiro.
  join -t, -j1 "$tmp/rankA.csv" "$tmp/rankB.csv" \
    | awk -F, '{print $1","($2+$3)}' \
    | sort -t, -k2,2n
}

case "${1:-}" in
  --priority) read_coverage_by_file 2>/dev/null | rank_priority || exit 1 ;;
  "") read_coverage 2>/dev/null || exit 1 ;;
  *) echo "Uso: coverage.sh [--priority]" >&2; exit 1 ;;
esac
