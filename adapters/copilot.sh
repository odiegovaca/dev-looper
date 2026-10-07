# adapters/copilot.sh — lido pelo install.sh com --agent copilot (o padrão).
#
# Instala no layout do GitHub Copilot Agent Mode: prompts em .github/prompts/.
# As instruções ficam no AGENTS.md da raiz, que o VS Code lê por padrão
# (chat.useAgentsMdFile).

export DL_PROMPTS_DIR='.github/prompts'
export DL_SCRIPTS_DIR='.github/scripts'
export DL_PROMPT_EXT='.prompt.md'
export DL_GUIDE_PATH='.github/prompts/README.md'
export DL_PROMPTS_PROTECTED='`.github/prompts/*.md`'
export DL_PROMPTS_PROTECTED_ECHO="echo '.github/prompts/*.md'"
export DL_FLOW_FILES='`.github/`, `AGENTS.md`'
export DL_TODO_LIST='`manage_todo_list`'

# Onde cada arquivo de core/ vai no projeto. Recebe o caminho relativo a core/.
destino() {
  case "$1" in
    prompts/*.md)             echo "$DL_PROMPTS_DIR/$(basename "$1" .md)$DL_PROMPT_EXT" ;;
    guide.md)                 echo "$DL_GUIDE_PATH" ;;
    instructions.template.md) echo "$TEMPLATE_INSTRUCOES" ;;
    scripts/*)                echo "$DL_SCRIPTS_DIR/${1#scripts/}" ;;
  esac
}

# Frontmatter neutro (stdin, sem os ---) → o do Copilot: agent mode logo depois
# da description, o resto na ordem em que veio.
frontmatter() {
  awk '{ print } /^description:/ { print "agent: agent" }'
}
