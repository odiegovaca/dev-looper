#!/usr/bin/env bash
# release-finalize.sh
# Resumo do PR via stdin.
#
# Confere o CHANGELOG consolidado, commita versão e CHANGELOG, faz push e abre o
# PR de release com o checklist padrão. Sem argumentos: branch de produção e
# versão saem do release-branches.sh e dos arquivos que o release-prepare.sh gravou,
# para o PR não sair nomeado com uma versão diferente da gravada.
# Imprime a confirmação pronta para o chat — usar a saída sem alterações.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BRANCHES="$("$SCRIPT_DIR/release-branches.sh")" || exit 1
eval "$BRANCHES"
RELEASE_VERSION="$("$SCRIPT_DIR/bump-version.sh" current)"

if [[ "$RELEASE_VERSION" == *-rc.* ]]; then
  echo "Versão nos arquivos ainda é $RELEASE_VERSION (RC) — rode o passo 1 (.github/scripts/release-prepare.sh) antes: é ele que corta a branch de release e grava a versão estável" >&2
  exit 1
fi

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

# Contrato com o release-postmerge.sh, checado enquanto ainda sai barato: sem a seção
# da versão ele fecha as issues sem a lista, e uma -rc.N que sobrou vai para produção.
if [ -f CHANGELOG.md ]; then
  HOJE="$(date +%d/%m/%Y)"
  RC_RESTANTE="$(grep -n "^## \[[^]]*-rc\." CHANGELOG.md 2>/dev/null || true)"
  # Casa por prefixo: o header da seção traz a data depois da versão.
  SECAO="$(awk -v hdr="## [$RELEASE_VERSION]" '
    index($0, hdr) == 1 { found=1; next }
    found && /^## / { exit }
    found { print }
  ' CHANGELOG.md 2>/dev/null | sed -e '/./,$!d' || true)"

  if [ -n "$RC_RESTANTE" ] || [ -z "$SECAO" ]; then
    echo "CHANGELOG.md não está consolidado — a seção do ciclo vem do /rc." >&2
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
    echo "   Deixe uma única seção '## [$RELEASE_VERSION] - $HOJE' com o delta do ciclo, sem nenhuma -rc.N." >&2
    exit 1
  fi
fi

git add .
"$SCRIPT_DIR/protect-stage.sh"
git diff --cached --quiet || git commit -m "chore: release v$RELEASE_VERSION"

CURRENT_BRANCH="$(git branch --show-current)"
git push origin "$CURRENT_BRANCH"

# Filtra por estado: sem isso, uma branch reaproveitada devolve o PR já mergeado
# e o script sai com 0.
EXISTING_PR="$(gh pr view "$CURRENT_BRANCH" --json url,state --jq 'select(.state == "OPEN") | .url' 2>/dev/null || true)"
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
