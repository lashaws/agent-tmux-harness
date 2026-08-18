#!/bin/bash
# terminal-setup.sh — replicate LaShaw's tmux setup on a new Mac.
# Installs tmux (+ iTerm2 app), writes ~/.tmux.conf and the cheatsheet, and adds
# the tmux auto-attach block to ~/.zshrc. iTerm appearance/keys are NOT managed
# here — configure that profile once in the UI (see README).
# Usage: copy this file to the new machine, then:  bash terminal-setup.sh
set -e

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

# 3. tmux config (backs up any existing one)
# NOTE: this script deliberately does NOT touch iTerm settings. Writing iTerm
# prefs from a script is unreliable -- iTerm holds its own in-memory copy and
# overwrites the plist on quit, so `defaults write` silently reverts. Set the
# profile up once in the UI instead; see README.
TMUX_TMP=$(mktemp "${TMPDIR:-/tmp}/tmux.conf.XXXXXX")
cat > "$TMUX_TMP" <<'TMUXCONF'
# ~/.tmux.conf — homebase setup
# Reload after edits: prefix + r  (or: tmux source-file ~/.tmux.conf)

# --- Quality of life ---
set -g mouse on                       # click panes/windows, scroll, drag to resize
set -g history-limit 100000           # deep scrollback for long agent output
set -sg escape-time 10                # no lag after pressing Esc (editors, Claude Code)
set -g focus-events on
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"  # true color
set -g set-clipboard on               # mouse-select in tmux → macOS clipboard (via iTerm OSC52)

# --- Numbering: start at 1, keep gaps closed ---
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# --- Intuitive splits (in addition to default % and ") ---
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"   # new window keeps current directory

# --- Fast config reload ---
bind r source-file ~/.tmux.conf \; display-message "tmux config reloaded"

# --- Theme: calm dark dashboard ---
set -g status-position top
set -g status-interval 5
set -g status-left-length 30
set -g status-style "bg=#181825,fg=#9399b2"
set -g status-left "#[fg=#181825,bg=#89b4fa,bold] #S #[default]  "
set -g status-right "#[fg=#9399b2]%a %b %d  #[fg=#cdd6f4,bold]%H:%M "
setw -g window-status-current-format "#[fg=#cdd6f4,bold]#I:#W"
setw -g window-status-format "#[fg=#585b70]#I:#W"
set -g window-status-separator "  "
set -g message-style "bg=#89b4fa,fg=#181825,bold"
set -g mode-style "bg=#45475a,fg=#cdd6f4"

# --- Panes: titled borders = the dashboard view ---
set -g pane-border-style "fg=#313244"
set -g pane-active-border-style "fg=#89b4fa"
set -g pane-border-status top
set -g pane-border-format " #{?pane_active,#[fg=#89b4fa]#[bold],#[fg=#585b70]}#{pane_index} · #{pane_current_command} #[default]"
set -g pane-border-lines heavy

# --- Keep sessions alive and titles useful ---
set -g set-titles on
set -g set-titles-string "#S:#W"
setw -g automatic-rename on
TMUXCONF
# Only back up when the content actually changes, so identical re-runs do not
# pile up .bak files.
if [ -f "$HOME/.tmux.conf" ] && ! cmp -s "$TMUX_TMP" "$HOME/.tmux.conf"; then
  cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak-$(date +%Y%m%d%H%M%S)"
  echo "==> Existing .tmux.conf backed up"
fi
mv "$TMUX_TMP" "$HOME/.tmux.conf"
echo "==> ~/.tmux.conf written"

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

# 4. Auto-attach block in .zshrc (idempotent — skips if already present)
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

# 5. Reload tmux if a server is already running
tmux source-file "$HOME/.tmux.conf" 2>/dev/null && echo "==> running tmux server reloaded" || true

echo ""
echo "DONE. tmux config and shell auto-attach are in place."
echo "iTerm appearance/keys are not managed by this script -- see README."
