# adapters/claude.sh — lido pelo install.sh com --agent claude.
#
# Instala no layout do Claude Code: comandos em .claude/commands/ e instruções em
# AGENTS.md, que o Claude Code carrega pelo `@AGENTS.md` do CLAUDE.md — ele não lê
# o AGENTS.md sozinho. Os scripts ficam em .github/scripts/, onde os prompts os chamam.

export DL_INSTRUCTIONS='AGENTS.md'
export DL_INSTRUCTIONS_PATH='AGENTS.md'
export DL_INSTRUCTIONS_TEMPLATE='AGENTS.template.md'
export DL_INSTRUCTIONS_TEMPLATE_PATH='AGENTS.template.md'
export DL_INSTRUCTIONS_TITLE='Agent Instructions'
export DL_PROMPTS_DIR='.claude/commands'
export DL_PROMPT_EXT='.md'
# Fora de commands/: lá dentro o guia viraria um comando /README.
export DL_GUIDE_PATH='.claude/dev-looper.md'
export DL_PROMPTS_PROTECTED='`.claude/commands/*.md`, `.claude/dev-looper.md`'
export DL_PROMPTS_PROTECTED_ECHO="echo '.claude/commands/*.md'
echo '.claude/dev-looper.md'"
export DL_FLOW_FILES='`.github/`, `.claude/`, `AGENTS.md`'
export DL_TODO_LIST='a lista de tarefas'

destino() {
  case "$1" in
    prompts/*.md)             echo "$DL_PROMPTS_DIR/$(basename "$1")" ;;
    guide.md)                 echo "$DL_GUIDE_PATH" ;;
    instructions.template.md) echo "$DL_INSTRUCTIONS_TEMPLATE_PATH" ;;
    scripts/*)                echo ".github/$1" ;;
  esac
}

# Do frontmatter neutro, o Claude Code usa description e argument-hint. `tools`
# fica de fora: virar allowed-tools liberaria Bash sem confirmação.
frontmatter() {
  grep -E '^(description|argument-hint):' || true
}

# Arquivos do adaptador que não vêm de core/, relativos a adapters/claude/.
EXTRAS=(CLAUDE.md)

# Chamada no fim do install.sh. O CLAUDE.md é do projeto quando já existe, então o
# install não o toca — mas sem o import o Claude Code não lê o AGENTS.md.
notas() {
  if [ -f "$DEST/CLAUDE.md" ] && ! grep -qxF '@AGENTS.md' "$DEST/CLAUDE.md"; then
    echo ""
    echo "Nota: o CLAUDE.md deste projeto não importa o AGENTS.md. Acrescente a linha"
    echo "@AGENTS.md a ele, senão o Claude Code não lê as instruções que o /setup gera."
  fi
}
