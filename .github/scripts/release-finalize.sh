#!/usr/bin/env bash
# release-finalize.sh <prod-branch> <release-version>
# Resumo do PR via stdin.
#
# Faz a parte 100% mecânica do passo 4 do /release: checagem de que o passo
# 2 consolidou o CHANGELOG, commit das mudanças de versão/CHANGELOG (sem
# falhar se não houver nada staged), push da branch atual, checagem de PR
# já aberto (sem criar duplicado nem editar
# automaticamente — só reporta, mesmo padrão do create-pr.sh) e a chamada
# ao `gh pr create` com o checklist padrão de release.
#
# Termina imprimindo a confirmação já pronta para colar no chat (mesmo
# padrão do create-pr.sh) — usar a saída sem alterações.
set -euo pipefail

PROD_BRANCH="${1:-}"
RELEASE_VERSION="${2:-}"

if [ -z "$PROD_BRANCH" ] || [ -z "$RELEASE_VERSION" ]; then
  echo "Uso: release-finalize.sh <prod-branch> <release-version>  (resumo via stdin)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BODY_SUMMARY="$(cat)"

# Orientação pós-merge: texto puro, impresso nas duas saídas do script.
print_postmerge_hint() {
  echo
  echo "📋 Depois do merge (não executar agora)"
  echo "   O PR ainda precisa ser revisado e mergeado."
  echo "   Assim que estiver mergeado, o passo final da entrega é:"
  echo
  echo "       .github/scripts/release-postmerge.sh $RELEASE_VERSION"
  echo
  echo "   Ele publica a tag v$RELEASE_VERSION, sincroniza a integração com $PROD_BRANCH"
  echo "   e fecha o ciclo de cada issue da release (issue, spec e reviews)."
  echo "   Se preferir, é só me pedir depois do merge que eu executo por você."
}

# Contrato com o release-postmerge.sh, checado no último ponto antes do PR em
# que ainda sai barato consertar. Ele monta o comentário de fechamento das
# issues copiando a seção cujo header começa exatamente por
# "## [$RELEASE_VERSION]" e, quando não acha, omite a lista em silêncio — a
# issue fecharia só com "Entregue na vX.Y.Z.". Mesmo casamento por prefixo
# usado lá, pra não divergirem. A segunda checagem é o outro lado: seção de RC
# é provisória, e uma esquecida pelo passo 2 não some mais — vai para
# produção e fica lá abaixo da seção boa, em toda release seguinte.
if [ -f CHANGELOG.md ]; then
  HOJE="$(date +%d/%m/%Y)"
  RC_RESTANTE="$(grep -n "^## \[[^]]*-rc\." CHANGELOG.md 2>/dev/null || true)"
  SECAO="$(awk -v hdr="## [$RELEASE_VERSION]" '
    index($0, hdr) == 1 { found=1; next }
    found && /^## / { exit }
    found { print }
  ' CHANGELOG.md 2>/dev/null | sed -e '/./,$!d' || true)"

  if [ -n "$RC_RESTANTE" ] || [ -z "$SECAO" ]; then
    echo "CHANGELOG.md não está consolidado — passo 2 do /release incompleto." >&2
    if [ -n "$RC_RESTANTE" ]; then
      echo "   Seções de RC ainda no arquivo:" >&2
      echo "$RC_RESTANTE" | head -5 | sed 's/^/     linha /' >&2
    fi
    if [ -z "$SECAO" ]; then
      if grep -q "^## \[$RELEASE_VERSION\]" CHANGELOG.md 2>/dev/null; then
        echo "   A seção ## [$RELEASE_VERSION] existe mas está vazia." >&2
      else
        echo "   Não há seção começando por '## [$RELEASE_VERSION]'." >&2
      fi
    fi
    echo "   Junte o conteúdo dos RCs em uma única seção '## [$RELEASE_VERSION] - $HOJE' e remova as seções -rc.N." >&2
    exit 1
  fi
fi

git add .
"$SCRIPT_DIR/protect-stage.sh"
git diff --cached --quiet || git commit -m "chore: release v$RELEASE_VERSION"

CURRENT_BRANCH="$(git branch --show-current)"
git push origin "$CURRENT_BRANCH"

EXISTING_PR="$(gh pr view "$CURRENT_BRANCH" --json url --jq .url 2>/dev/null || true)"
if [ -n "$EXISTING_PR" ]; then
  echo "⚠️ Já existe um PR aberto para esta branch: $EXISTING_PR"
  echo "   Push aplicado com as mudanças mais recentes; nenhum PR novo foi criado."
  print_postmerge_hint
  exit 0
fi

BODY="## Release v$RELEASE_VERSION

### Resumo das mudanças
$BODY_SUMMARY

### Checklist
- [x] Todos os testes passando
- [x] CHANGELOG consolidado
- [x] Versões atualizadas
- [ ] Revisado por pelo menos 1 desenvolvedor"

PR_URL="$(gh pr create --base "$PROD_BRANCH" --title "release: v$RELEASE_VERSION" --body "$BODY")"

echo "✅ PR criado: $PR_URL"
echo "   Versão: $RELEASE_VERSION"
echo "   Base: $PROD_BRANCH ← $CURRENT_BRANCH"
print_postmerge_hint
