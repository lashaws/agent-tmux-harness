#!/bin/bash
# terminal-setup.sh — replicate LaShaw's complete tmux + iTerm setup on a new Mac.
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

# 3. iTerm profile: exact font, palette, key mappings, and terminal behavior.
# Dynamic Profiles are monitored by iTerm and keep this setup separate from any
# profiles that already exist on the destination Mac.
ITERM_PROFILE_GUID="7D4DE2F5-3D26-4CDD-8456-080AA2EAB72F"
ITERM_PROFILE_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
ITERM_PROFILE_PATH="$ITERM_PROFILE_DIR/lashaw-homebase.json"
ITERM_PROFILE_TMP=$(mktemp "${TMPDIR:-/tmp}/lashaw-homebase.XXXXXX")
trap 'rm -f "$ITERM_PROFILE_TMP"' EXIT

cat > "$ITERM_PROFILE_TMP" <<'ITERM_PROFILE'
{
  "Profiles": [
    {
      "Name": "LaShaw Homebase",
      "Description": "LaShaw Homebase",
      "Guid": "7D4DE2F5-3D26-4CDD-8456-080AA2EAB72F",
      "Dynamic Profile Parent Name": "Default",
      "Normal Font": "Monaco 12",
      "Non Ascii Font": "Monaco 12",
      "Use Non-ASCII Font": false,
      "ASCII Anti Aliased": true,
      "Non-ASCII Anti Aliased": true,
      "Use Bold Font": true,
      "Use Bright Bold": true,
      "Use Italic Font": true,
      "Horizontal Spacing": 1,
      "Vertical Spacing": 1,
      "Columns": 80,
      "Rows": 25,
      "Transparency": 0,
      "Blur": false,
      "Terminal Type": "xterm-256color",
      "Unlimited Scrollback": false,
      "Scrollback Lines": 1000,
      "Mouse Reporting": true,
      "Blinking Cursor": false,
      "Visual Bell": true,
      "Flashing Bell": false,
      "Silence Bell": false,
      "Disable Window Resizing": true,
      "Prompt Before Closing 2": false,
      "Custom Command": "No",
      "Custom Directory": "No",
      "Option Key Sends": 0,
      "Right Option Key Sends": 0,
      "Use Separate Colors for Light and Dark Mode": true,

      "Ansi 0 Color": {"Red Component":0.0784313753247261,"Green Component":0.09803921729326248,"Blue Component":0.1176470592617989,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 0 Color (Dark)": {"Red Component":0.0784313753247261,"Green Component":0.09803921729326248,"Blue Component":0.1176470592617989,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 0 Color (Light)": {"Red Component":0.0784313753247261,"Green Component":0.09803921729326248,"Blue Component":0.1176470592617989,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 1 Color": {"Red Component":0.7074432373046875,"Green Component":0.2366006970405579,"Blue Component":0.1630003750324249,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 1 Color (Dark)": {"Red Component":0.7074432373046875,"Green Component":0.2366006970405579,"Blue Component":0.1630003750324249,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 1 Color (Light)": {"Red Component":0.7074432373046875,"Green Component":0.2366006970405579,"Blue Component":0.1630003750324249,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 2 Color": {"Red Component":0,"Green Component":0.7607843279838562,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 2 Color (Dark)": {"Red Component":0,"Green Component":0.7607843279838562,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 2 Color (Light)": {"Red Component":0,"Green Component":0.7607843279838562,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 3 Color": {"Red Component":0.7805864810943604,"Green Component":0.7695948481559753,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 3 Color (Dark)": {"Red Component":0.7805864810943604,"Green Component":0.7695948481559753,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 3 Color (Light)": {"Red Component":0.7805864810943604,"Green Component":0.7695948481559753,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 4 Color": {"Red Component":0.1540430039167404,"Green Component":0.2647435665130615,"Blue Component":0.7821617722511292,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 4 Color (Dark)": {"Red Component":0.1540430039167404,"Green Component":0.2647435665130615,"Blue Component":0.7821617722511292,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 4 Color (Light)": {"Red Component":0.1540430039167404,"Green Component":0.2647435665130615,"Blue Component":0.7821617722511292,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 5 Color": {"Red Component":0.752197265625,"Green Component":0.2493168413639069,"Blue Component":0.7449436187744141,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 5 Color (Dark)": {"Red Component":0.752197265625,"Green Component":0.2493168413639069,"Blue Component":0.7449436187744141,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 5 Color (Light)": {"Red Component":0.752197265625,"Green Component":0.2493168413639069,"Blue Component":0.7449436187744141,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 6 Color": {"Red Component":0,"Green Component":0.7742590308189392,"Blue Component":0.7816620469093323,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 6 Color (Dark)": {"Red Component":0,"Green Component":0.7742590308189392,"Blue Component":0.7816620469093323,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 6 Color (Light)": {"Red Component":0,"Green Component":0.7742590308189392,"Blue Component":0.7816620469093323,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 7 Color": {"Red Component":0.7810397744178772,"Green Component":0.7810582518577576,"Blue Component":0.7810482978820801,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 7 Color (Dark)": {"Red Component":0.7810397744178772,"Green Component":0.7810582518577576,"Blue Component":0.7810482978820801,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 7 Color (Light)": {"Red Component":0.7810397744178772,"Green Component":0.7810582518577576,"Blue Component":0.7810482978820801,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 8 Color": {"Red Component":0.4078176021575928,"Green Component":0.4078278839588165,"Blue Component":0.4078223705291748,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 8 Color (Dark)": {"Red Component":0.4078176021575928,"Green Component":0.4078278839588165,"Blue Component":0.4078223705291748,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 8 Color (Light)": {"Red Component":0.4078176021575928,"Green Component":0.4078278839588165,"Blue Component":0.4078223705291748,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 9 Color": {"Red Component":0.8659515380859375,"Green Component":0.4752407670021057,"Blue Component":0.4583322405815125,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 9 Color (Dark)": {"Red Component":0.8659515380859375,"Green Component":0.4752407670021057,"Blue Component":0.4583322405815125,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 9 Color (Light)": {"Red Component":0.8659515380859375,"Green Component":0.4752407670021057,"Blue Component":0.4583322405815125,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 10 Color": {"Red Component":0.3450070321559906,"Green Component":0.9042816162109375,"Blue Component":0.5654193758964539,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 10 Color (Dark)": {"Red Component":0.3450070321559906,"Green Component":0.9042816162109375,"Blue Component":0.5654193758964539,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 10 Color (Light)": {"Red Component":0.3450070321559906,"Green Component":0.9042816162109375,"Blue Component":0.5654193758964539,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 11 Color": {"Red Component":0.9259033203125,"Green Component":0.8833775520324707,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 11 Color (Dark)": {"Red Component":0.9259033203125,"Green Component":0.8833775520324707,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 11 Color (Light)": {"Red Component":0.9259033203125,"Green Component":0.8833775520324707,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 12 Color": {"Red Component":0.6534907817840576,"Green Component":0.6704471707344055,"Blue Component":0.9485321044921875,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 12 Color (Dark)": {"Red Component":0.6534907817840576,"Green Component":0.6704471707344055,"Blue Component":0.9485321044921875,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 12 Color (Light)": {"Red Component":0.6534907817840576,"Green Component":0.6704471707344055,"Blue Component":0.9485321044921875,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 13 Color": {"Red Component":0.8821563720703125,"Green Component":0.4927266538143158,"Blue Component":0.8821563720703125,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 13 Color (Dark)": {"Red Component":0.8821563720703125,"Green Component":0.4927266538143158,"Blue Component":0.8821563720703125,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 13 Color (Light)": {"Red Component":0.8821563720703125,"Green Component":0.4927266538143158,"Blue Component":0.8821563720703125,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 14 Color": {"Red Component":0.3759753108024597,"Green Component":0.9926329255104065,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 14 Color (Dark)": {"Red Component":0.3759753108024597,"Green Component":0.9926329255104065,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 14 Color (Light)": {"Red Component":0.3759753108024597,"Green Component":0.9926329255104065,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 15 Color": {"Red Component":0.9999960064888,"Green Component":1,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 15 Color (Dark)": {"Red Component":0.9999960064888,"Green Component":1,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Ansi 15 Color (Light)": {"Red Component":0.9999960064888,"Green Component":1,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},

      "Background Color": {"Red Component":0.98,"Green Component":0.98,"Blue Component":0.98,"Alpha Component":1,"Color Space":"sRGB"},
      "Background Color (Light)": {"Red Component":0.98,"Green Component":0.98,"Blue Component":0.98,"Alpha Component":1,"Color Space":"sRGB"},
      "Background Color (Dark)": {"Red Component":0.0806884765625,"Green Component":0.09911105036735535,"Blue Component":0.12103271484375,"Alpha Component":1,"Color Space":"sRGB"},
      "Foreground Color": {"Red Component":0.062745101749897,"Green Component":0.062745101749897,"Blue Component":0.062745101749897,"Alpha Component":1,"Color Space":"sRGB"},
      "Foreground Color (Light)": {"Red Component":0.06274509803921569,"Green Component":0.06274509803921569,"Blue Component":0.06274509803921569,"Alpha Component":1,"Color Space":"sRGB"},
      "Foreground Color (Dark)": {"Red Component":0.8619791269302368,"Green Component":0.86199951171875,"Blue Component":0.8619885444641113,"Alpha Component":1,"Color Space":"sRGB"},
      "Bold Color": {"Red Component":0.062745101749897,"Green Component":0.062745101749897,"Blue Component":0.062745101749897,"Alpha Component":1,"Color Space":"sRGB"},
      "Bold Color (Light)": {"Red Component":0.06274509803921569,"Green Component":0.06274509803921569,"Blue Component":0.06274509803921569,"Alpha Component":1,"Color Space":"sRGB"},
      "Bold Color (Dark)": {"Red Component":0.9999960064888,"Green Component":1,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Cursor Color": {"Red Component":0,"Green Component":0,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Cursor Color (Light)": {"Red Component":0,"Green Component":0,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Cursor Color (Dark)": {"Red Component":0.9999763369560242,"Green Component":1,"Blue Component":0.9999872446060181,"Alpha Component":1,"Color Space":"sRGB"},
      "Cursor Text Color": {"Red Component":1,"Green Component":1,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Cursor Text Color (Light)": {"Red Component":1,"Green Component":1,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Cursor Text Color (Dark)": {"Red Component":0,"Green Component":0,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Selection Color": {"Red Component":0.7019608020782471,"Green Component":0.843137264251709,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Selection Color (Light)": {"Red Component":0.7019608020782471,"Green Component":0.843137264251709,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Selection Color (Dark)": {"Red Component":0.7019608020782471,"Green Component":0.843137264251709,"Blue Component":1,"Alpha Component":1,"Color Space":"sRGB"},
      "Selected Text Color": {"Red Component":0,"Green Component":0,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Selected Text Color (Light)": {"Red Component":0,"Green Component":0,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Selected Text Color (Dark)": {"Red Component":0,"Green Component":0,"Blue Component":0,"Alpha Component":1,"Color Space":"sRGB"},
      "Link Color": {"Red Component":0.1980242282152176,"Green Component":0.5578983426094055,"Blue Component":0.9337158203125,"Alpha Component":1,"Color Space":"sRGB"},
      "Link Color (Light)": {"Red Component":0.1980242282152176,"Green Component":0.5578983426094055,"Blue Component":0.9337158203125,"Alpha Component":1,"Color Space":"sRGB"},
      "Link Color (Dark)": {"Red Component":0.1980242282152176,"Green Component":0.5578983426094055,"Blue Component":0.9337158203125,"Alpha Component":1,"Color Space":"sRGB"},
      "Badge Color": {"Red Component":0.7461385726928711,"Green Component":0.1161063313484192,"Blue Component":0.1161063313484192,"Alpha Component":0.5,"Color Space":"sRGB"},
      "Badge Color (Light)": {"Red Component":0.7461385726928711,"Green Component":0.1161063305839889,"Blue Component":0.1161063305839889,"Alpha Component":0.5,"Color Space":"sRGB"},
      "Badge Color (Dark)": {"Red Component":0.9787440299987793,"Green Component":0.6521859746214886,"Blue Component":0.6521859746214886,"Alpha Component":0.5,"Color Space":"sRGB"},
      "Cursor Guide Color": {"Red Component":0.5233826041221619,"Green Component":0.7721771597862244,"Blue Component":0.8531928062438965,"Alpha Component":0.25,"Color Space":"sRGB"},
      "Cursor Guide Color (Light)": {"Red Component":0.5233826264372965,"Green Component":0.7721771862908952,"Blue Component":0.8531928062438965,"Alpha Component":0.25,"Color Space":"sRGB"},
      "Cursor Guide Color (Dark)": {"Red Component":0.3764958801639295,"Green Component":0.8023261774920553,"Blue Component":0.9409904479980469,"Alpha Component":0.25,"Color Space":"sRGB"},

      "Keyboard Map": {
        "0xf728-0x0": {"Action":11,"Text":"0x4"},
        "0xf702-0x280000": {"Action":10,"Text":"b"},
        "0xf702-0x300000": {"Action":11,"Text":"0x1"},
        "0xf728-0x80000": {"Action":10,"Text":"d"},
        "0xf703-0x280000": {"Action":10,"Text":"f"},
        "0x7f-0x100000": {"Action":11,"Text":"0x15"},
        "0x7f-0x80000": {"Action":11,"Text":"0x1b 0x7f"},
        "0xf703-0x300000": {"Action":11,"Text":"0x5"}
      }
    }
  ]
}
ITERM_PROFILE

mkdir -p "$ITERM_PROFILE_DIR"
if [ -f "$ITERM_PROFILE_PATH" ] && ! cmp -s "$ITERM_PROFILE_TMP" "$ITERM_PROFILE_PATH"; then
  cp "$ITERM_PROFILE_PATH" "$ITERM_PROFILE_PATH.bak-$(date +%Y%m%d%H%M%S)"
  echo "==> Existing managed iTerm profile backed up"
fi
mv "$ITERM_PROFILE_TMP" "$ITERM_PROFILE_PATH"
trap - EXIT

# These are global iTerm settings. The profile itself supplies Natural Text
# Editing, so no manual Preferences steps are required.
defaults write com.googlecode.iterm2 AllowClipboardAccess -bool true
defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$ITERM_PROFILE_GUID"
echo "==> iTerm profile 'LaShaw Homebase' installed and made default"

# 4. tmux config (backs up any existing one)
if [ -f "$HOME/.tmux.conf" ]; then
  cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak-$(date +%Y%m%d%H%M%S)"
  echo "==> Existing .tmux.conf backed up"
fi
cat > "$HOME/.tmux.conf" <<'TMUXCONF'
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
| Move between panes         | `Alt+arrow keys` (or just click a pane)   |
| Resize a pane              | drag the border with the mouse            |
| Zoom a pane full-screen    | `Ctrl-b` then `z` (again to un-zoom)      |
| Close a pane               | type `exit` (or `Ctrl-d`)                 |
| Scroll back                | mouse wheel; `q` to jump back to live     |

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
echo "DONE. No manual Preferences steps remain."
echo "If iTerm was open during setup, quit it once with Cmd-Q and reopen it."
echo "Every new iTerm window then uses the matching colors and attaches to tmux home."
