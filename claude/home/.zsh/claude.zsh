# claude.zsh — Claude Code shell wiring (tracked in ~/dotfiles/claude/home/.zsh/claude.zsh).

# --- Claude Code accounts ---
# Sessions started anywhere under ~/work use their own config dir (~/.claude-work), which
# gives them their own macOS Keychain credential item. Everywhere else,
# account rotation applies: `claude-account pick` (accounts in ~/.claude/local/accounts.tsv)
# chooses the account, pinned or auto-rotated when usage nears the threshold. The default
# account must run with CLAUDE_CONFIG_DIR UNSET (its login lives in the default Keychain
# item); other accounts share ~/.claude's harness through symlinks. Launchd/cron automation
# never sources .zshrc and keeps using ~/.claude.
claude() {
  if [[ -n "$CLAUDE_CONFIG_DIR" ]]; then
    command claude "$@"
  elif [[ "$PWD" == "$HOME/work"(|/*) ]]; then
    CLAUDE_CONFIG_DIR="$HOME/.claude-work" command claude "$@"
  else
    local dir
    dir=$("$HOME/.claude/bin/claude-account" pick)
    if [[ -n "$dir" ]]; then
      CLAUDE_CONFIG_DIR="$dir" command claude "$@"
    else
      command claude "$@"
    fi
  fi
}
alias ca="$HOME/.claude/bin/claude-account"

# Attach-or-create one tmux session per Claude account. Starting each session
# with -c pins its base dir, so every pane (prefix c / | / - / % / ") inherits a
# cwd on the correct side of the ~/work boundary.
# Nesting-aware: .zshrc auto-attaches every terminal to the "home" session, so
# these usually run from INSIDE tmux, where `new-session -A` refuses to nest.
_tsess() {  # $1=session name  $2=base dir
  tmux has-session -t "$1" 2>/dev/null || tmux new-session -d -s "$1" -c "$2"
  if [ -n "$TMUX" ]; then tmux switch-client -t "$1"; else tmux attach-session -t "$1"; fi
}
twork() { _tsess work "$HOME/work/quantum"; }
twiki() { _tsess wiki "$HOME/life-wiki"; }

# your-turn: mark handed-over commands done when Lashaw runs them in tmux.
[ -f ~/.zsh/your-turn-watch.zsh ] && source ~/.zsh/your-turn-watch.zsh
