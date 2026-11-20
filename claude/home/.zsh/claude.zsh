# claude.zsh — Claude Code shell wiring (tracked in ~/dotfiles/claude/home/.zsh/claude.zsh).

# --- Claude Code: separate account for ~/work (added 2026-08-25) ---
# Sessions started anywhere under ~/work use their own config dir, which gives
# them their own macOS Keychain credential item ("Claude Code-credentials-<hash>").
# Everything else — including all launchd/cron automation, which never sources
# .zshrc — keeps using ~/.claude and the default login.
claude() {
  if [[ -z "$CLAUDE_CONFIG_DIR" && "$PWD" == "$HOME/work"(|/*) ]]; then
    CLAUDE_CONFIG_DIR="$HOME/.claude-work" command claude "$@"
  else
    command claude "$@"
  fi
}

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
