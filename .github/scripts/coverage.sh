#!/usr/bin/env bash
# coverage.sh [--priority|--target] — imprime a cobertura de statements do
# relatório já gerado (sem rodar os testes de novo). Falha nomeando o motivo
# quando não há número para dar: ver cobertura_indisponivel() abaixo.
set -euo pipefail

# Caminho do relatorio lido pelas duas funcoes abaixo — preenchido por /setup.
# So alimenta warn_if_stale(); vazio, o aviso nao sai e o resto funciona igual.
COVERAGE_REPORT=""  # [DEFINIR: caminho do relatorio que os testes geram]

# Meta de statements do projeto, em %. Dono unico do numero: o /test compara
# contra ele e o /status o exibe, em vez de cada um carregar seu 80 embutido.
COVERAGE_TARGET="80"  # [DEFINIR pelo /setup: meta do projeto, so o numero]

# Consumido pelo /status e pela checagem de meta do /test.
read_coverage() {
  # [DEFINIR: comando que le COVERAGE_REPORT e imprime uma unica linha — a
  # cobertura total de statements em %, so o numero, sem o sinal de porcento]
  return 1
}

# Insumo do --priority via rank_priority() abaixo, que o /test usa para escolher
# onde escrever teste sem depender de cálculo manual.
read_coverage_by_file() {
  # [DEFINIR: comando que le COVERAGE_REPORT e imprime uma linha por arquivo,
  # sem cabecalho e sem a linha de total: caminho,pct,total_statements — pct so
  # o numero, e 3a coluna vazia se o stack nao expuser total por arquivo]
  return 1
}

# Avisa quando o relatorio e mais velho que o ultimo commit — mede codigo que ja
# mudou. E o unico detector do comando de teste sem cobertura (ver run_test no
# validate.sh) depois da instalacao. Compara com o commit, e nao com o arquivo
# mais novo da arvore, para nao gritar a cada edicao. Aviso em stderr, nunca
# falha e nunca segura o numero.
warn_if_stale() {
  [ -n "$COVERAGE_REPORT" ] && [ -f "$COVERAGE_REPORT" ] || return 0

  local head_ts report_ts
  head_ts="$(git log -1 --format=%ct 2>/dev/null)" || return 0
  report_ts="$(stat -c %Y "$COVERAGE_REPORT" 2>/dev/null || stat -f %m "$COVERAGE_REPORT" 2>/dev/null)" || return 0
  [ -n "$head_ts" ] && [ -n "$report_ts" ] || return 0

  if [ "$report_ts" -lt "$head_ts" ]; then
    echo "Aviso: $COVERAGE_REPORT é mais antigo que o último commit — a cobertura abaixo pode não refletir o código atual." >&2
    echo "       Se continuar assim depois de um \`validate.sh test\`, o comando de teste não está gerando cobertura." >&2
  fi
}

# Lê "arquivo,pct,total_statements" do stdin, imprime "arquivo,rank_sum"
# ordenado por prioridade (menor rank_sum primeiro).
# A soma dos dois ranks abaixo combina pct baixo E alto volume de statements
# não cobertos, em vez do pior pct isolado — que favoreceria arquivo pequeno e
# trivial sobre arquivo grande com gap real. É por isso que o /test segue esta
# ordem em vez de estimar onde testar: o ganho no % global sai daqui calculado.
# Genérica por construção — o /setup não preenche nada aqui; sem a 3ª coluna
# cai para ordenar só por pct.
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

# Sem numero para dar, o motivo sai nomeado: um exit 1 calado aqui vira "/test"
# eterno no /status (a regra de cobertura indisponivel vem antes de review e rc
# na cascata de NEXT_STEP), e "relatorio velho" nao se conserta como "/setup
# nunca configurou isto".
cobertura_indisponivel() {
  if [ -z "$COVERAGE_REPORT" ]; then
    echo "coverage.sh não configurado (COVERAGE_REPORT vazio e read_coverage sem corpo) — rode /setup" >&2
  elif [ ! -f "$COVERAGE_REPORT" ]; then
    echo "Relatório de cobertura não encontrado em $COVERAGE_REPORT — rode .github/scripts/validate.sh test para gerá-lo" >&2
  else
    echo "Não foi possível ler a cobertura de $COVERAGE_REPORT — confira read_coverage em coverage.sh (preenchido pelo /setup)" >&2
  fi
  exit 1
}

case "${1:-}" in
  --priority) warn_if_stale; read_coverage_by_file | rank_priority || cobertura_indisponivel ;;
  --target) echo "$COVERAGE_TARGET" ;;
  "") warn_if_stale; read_coverage || cobertura_indisponivel ;;
  *) echo "Uso: coverage.sh [--priority|--target]" >&2; exit 1 ;;
esac
