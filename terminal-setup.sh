#!/bin/bash
# terminal-setup.sh — replicate LaShaw's tmux + statusline setup on a new Mac.
# Installs tmux (+ iTerm2 app), installs ~/.tmux.conf, the Claude Code
# statusline script(s), and the cheatsheet, and adds the tmux auto-attach
# block to ~/.zshrc. iTerm appearance/keys are NOT managed here — configure
# that profile once in the UI (see README).
# Usage: clone the whole dotfiles repo (this script reads sibling files), then:
#   bash terminal-setup.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Terminal setup: tmux dashboard + auto-attach"

# 1. Homebrew (required)
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is missing. Install it first:"
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  echo "Then re-run this script."
  exit 1
fi

# 2. tmux + iTerm2
command -v tmux >/dev/null 2>&1 || brew install tmux
[ -d "/Applications/iTerm.app" ] || brew install --cask iterm2

# 3. tmux config (backs up any existing one, only if content actually changed)
# NOTE: this script deliberately does NOT touch iTerm settings. Writing iTerm
# prefs from a script is unreliable -- iTerm holds its own in-memory copy and
# overwrites the plist on quit, so `defaults write` silently reverts. Set the
# profile up once in the UI instead; see README.
if [ -f "$HOME/.tmux.conf" ] && ! cmp -s "$SCRIPT_DIR/tmux.conf" "$HOME/.tmux.conf"; then
  cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak-$(date +%Y%m%d%H%M%S)"
  echo "==> Existing .tmux.conf backed up"
fi
cp "$SCRIPT_DIR/tmux.conf" "$HOME/.tmux.conf"
echo "==> ~/.tmux.conf installed"

# 3b. Copy-last-output tooling: the prefix y/Y/S/C-s bindings above call this
# script, which relies on the zsh hooks to know where each command's output
# starts and ends in the pane's scrollback.
mkdir -p "$HOME/.local/bin" "$HOME/.zsh"
cp "$SCRIPT_DIR/tmux-last-output" "$HOME/.local/bin/tmux-last-output"
chmod +x "$HOME/.local/bin/tmux-last-output"
cp "$SCRIPT_DIR/tmux-last-output.zsh" "$HOME/.zsh/tmux-last-output.zsh"
echo "==> ~/.local/bin/tmux-last-output and ~/.zsh/tmux-last-output.zsh installed"
if ! grep -q 'tmux-last-output.zsh' "$HOME/.zshrc" 2>/dev/null; then
  cat >> "$HOME/.zshrc" <<'ZSHRC'

# Stamp tmux panes with command output ranges, for prefix y/Y/S/C-s
[ -f ~/.zsh/tmux-last-output.zsh ] && source ~/.zsh/tmux-last-output.zsh
ZSHRC
  echo "==> tmux-last-output source line added to ~/.zshrc"
else
  echo "==> tmux-last-output source line already in ~/.zshrc, skipped"
fi
if ! command -v pbcopy >/dev/null 2>&1; then
  echo "    NOTE: pbcopy not found — the clipboard modes (prefix y/S) need macOS."
fi

cat > "$HOME/tmux-cheatsheet.md" <<'CHEAT'
# tmux cheat sheet

Your setup: every new terminal auto-attaches to the shared **home** session.
The "prefix" is **Ctrl-b** — press it, release, then press the next key.

## The dashboard (panes)

| Do this                    | How                                      |
|----------------------------|------------------------------------------|
| Split side-by-side         | `Ctrl-b` then `\|`                        |
| Split top/bottom           | `Ctrl-b` then `-`                         |
| Move between panes         | click a pane, or `Ctrl-b` then an arrow key |
| Resize a pane              | drag the border with the mouse, or `Ctrl-b` then `Option+arrow` |
| Zoom a pane full-screen    | `Ctrl-b` then `z` (again to un-zoom)      |
| Close a pane               | type `exit` (or `Ctrl-d`)                 |
| Scroll back                | mouse wheel; `q` to jump back to live     |

Note: `Option+arrow` on its own does **not** switch panes — this iTerm profile sends
it to your shell as jump-one-word-left/right. Pane moves always need the `Ctrl-b`
prefix first (or just click).

## Sessions (your workspaces — survive closing the window)

| Do this                        | How                                  |
|--------------------------------|---------------------------------------|
| Detach (leave everything running) | `Ctrl-b` then `d`                  |
| Come back                      | open any terminal (auto-attaches), or `tmux attach -t home` |
| List sessions                  | `tmux ls`                             |
| Switch session (picker)        | `Ctrl-b` then `s`                     |
| New named session              | `tmux new -s projectname`             |

## Misc

| Do this                    | How                                      |
|----------------------------|-------------------------------------------|
| Reload config after edits  | `Ctrl-b` then `r`                         |
| Rename current session     | `Ctrl-b` then `$`                         |
| Copy text                  | hold `Option` while dragging (iTerm), or drag-select normally and it auto-copies |

**The one habit to build:** stop closing terminal windows to "clean up" — detach
(`Ctrl-b d`) instead. Everything keeps running and is there when you come back.

Config lives at `~/.tmux.conf`. This file: `~/tmux-cheatsheet.md` (delete anytime).
CHEAT
echo "==> ~/tmux-cheatsheet.md written"

# 4. Claude Code status line (personal account; work account too if ~/.claude-work exists)
install_statusline() {
  local src="$1" dest_dir="$2" dest="$dest_dir/statusline.sh"
  [ -d "$dest_dir" ] || return 0
  if [ -f "$dest" ] && ! cmp -s "$src" "$dest"; then
    cp "$dest" "$dest.bak-$(date +%Y%m%d%H%M%S)"
    echo "==> Existing $dest backed up"
  fi
  cp "$src" "$dest"
  chmod +x "$dest"
  echo "==> $dest installed"
}
install_statusline "$SCRIPT_DIR/statusline.sh" "$HOME/.claude"
install_statusline "$SCRIPT_DIR/statusline-work.sh" "$HOME/.claude-work"
echo "    NOTE: statusline only shows up if that account's settings.json has:"
echo '      "statusLine": {"type": "command", "command": "$HOME/.claude/statusline.sh"}'

# 5. Auto-attach block in .zshrc (idempotent — skips if already present)
if ! grep -q 'tmux new-session -A -s home' "$HOME/.zshrc" 2>/dev/null; then
  cat >> "$HOME/.zshrc" <<'ZSHRC'

# Auto-start tmux: every interactive terminal attaches to the shared "home" session.
# Detach (leave tmux running) with: Ctrl-b then d
if command -v tmux >/dev/null 2>&1 \
   && [ -z "$TMUX" ] \
   && [[ $- == *i* ]] \
   && [ "$TERM_PROGRAM" != "vscode" ]; then
  tmux new-session -A -s home
fi
ZSHRC
  echo "==> auto-attach block added to ~/.zshrc"
else
  echo "==> auto-attach already in ~/.zshrc, skipped"
fi

# 6. Reload tmux if a server is already running
tmux source-file "$HOME/.tmux.conf" 2>/dev/null && echo "==> running tmux server reloaded" || true

echo ""
echo "DONE. tmux config and shell auto-attach are in place."
echo "iTerm appearance/keys are not managed by this script -- see README."
