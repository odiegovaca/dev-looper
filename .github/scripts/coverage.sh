#!/usr/bin/env bash
# coverage.sh [--priority|--target] — imprime a cobertura de statements do relatório
# já gerado (sem rodar os testes). --priority devolve onde testar, em FASE1 (arquivos
# da branch) e FASE2 (o resto). Falha nomeando o motivo quando não há número para dar.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Relatório lido pelas duas funções abaixo; vazio, só desliga warn_if_stale().
COVERAGE_REPORT=""  # [DEFINIR: caminho do relatorio que os testes geram]

# Meta de statements do projeto, em % — dono único do número.
COVERAGE_TARGET=""  # [DEFINIR: meta de statements do projeto, so o numero, sem o %]

read_coverage() {
  # [DEFINIR: comando que le COVERAGE_REPORT e imprime uma unica linha — a
  # cobertura total de statements em %, so o numero, sem o sinal de porcento]
  return 1
}

# Insumo do --priority, via rank_priority() abaixo.
read_coverage_by_file() {
  # [DEFINIR: comando que le COVERAGE_REPORT e imprime "caminho,pct,total_statements"
  # por arquivo, sem cabecalho nem total; pct so o numero, 3a coluna vazia se nao houver.
  # Caminho relativo a raiz do repositorio e com "/", como o changed-files.sh devolve]
  return 1
}

# Avisa em stderr quando o relatório é mais velho que o último commit — mede código
# que já mudou. Compara com o commit, não com a árvore, para não gritar a cada edição.
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

# Lê "arquivo,pct,total_statements", imprime "arquivo,rank_sum" por prioridade — a soma
# dos dois ranks combina pct baixo E volume não coberto, que o pior pct isolado não faz.
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

# Separa o ranking em Fase 1 (arquivos da branch) e Fase 2 (o resto do projeto,
# até 10). Sem conseguir a lista da branch, tudo sai como Fase 1, na ordem do rank.
fases() {
  local alterados fase1 fase2
  alterados="$(
    BRANCHES="$("$SCRIPT_DIR/release-branches.sh" 2>/dev/null)" \
      && eval "$BRANCHES" \
      && "$SCRIPT_DIR/changed-files.sh" "$INTEGRATION_BRANCH" 2>/dev/null
  )" || alterados=""

  if [ -z "$alterados" ]; then
    echo "Aviso: não consegui listar os arquivos da branch — o ranking abaixo é do projeto inteiro." >&2
    echo "FASE1:"
    cat
    echo "FASE2:"
    return 0
  fi

  local ranked
  ranked="$(cat)"
  fase1="$(grep -F -f <(printf '%s\n' "$alterados") <<< "$ranked" || true)"
  fase2="$(grep -F -v -f <(printf '%s\n' "$alterados") <<< "$ranked" | head -10 || true)"

  # FASE1 vazia por formato de caminho incompatível passa despercebida — o --priority
  # segue plausível, só que todo em FASE2. O teste do arquivo separa isso de uma branch só de doc.
  if [ -z "$fase1" ] && [ -n "$ranked" ]; then
    local amostra
    amostra="$(head -1 <<< "$ranked" | cut -d, -f1)"
    if [ ! -e "$amostra" ]; then
      echo "Aviso: nenhum arquivo da branch casou com o relatório de cobertura, e o primeiro caminho dele ('$amostra') não existe a partir da raiz do repositório." >&2
      echo "       Confira read_coverage_by_file em coverage.sh: o caminho tem de ser relativo à raiz do repositório e com \"/\"." >&2
    fi
  fi

  echo "FASE1:"
  [ -z "$fase1" ] || printf '%s\n' "$fase1"
  echo "FASE2:"
  [ -z "$fase2" ] || printf '%s\n' "$fase2"
}

# Sem número para dar, o motivo sai nomeado: "relatório velho" não se conserta
# do mesmo jeito que "/setup nunca configurou isto".
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
  --priority) warn_if_stale; read_coverage_by_file | rank_priority | fases || cobertura_indisponivel ;;
  --target)
    [ -n "$COVERAGE_TARGET" ] || { echo "COVERAGE_TARGET não configurado em coverage.sh — rode /setup" >&2; exit 1; }
    echo "$COVERAGE_TARGET"
    ;;
  "") warn_if_stale; read_coverage || cobertura_indisponivel ;;
  *) echo "Uso: coverage.sh [--priority|--target]" >&2; exit 1 ;;
esac
