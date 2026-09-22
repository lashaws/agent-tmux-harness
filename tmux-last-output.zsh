# ~/.zsh/tmux-last-output.zsh — stamp each tmux pane with where the last
# command's output starts/ends, so `prefix y` (tmux-last-output) can copy exactly
# that range even when it is thousands of lines long. Two cheap tmux calls per
# command; no-op outside tmux.
[[ -n $TMUX && -n $TMUX_PANE ]] || return 0
autoload -Uz add-zsh-hook

_tlo_preexec() {
  # Runs after Enter, before the command: cursor sits on the first output line.
  local h; h=$(command tmux display -p -t "$TMUX_PANE" '#{history_size} #{cursor_y}' 2>/dev/null) || return 0
  command tmux set -p -t "$TMUX_PANE" @cmd_start $(( ${h% *} + ${h#* } )) \; \
               set -pu -t "$TMUX_PANE" @cmd_end 2>/dev/null
}
_tlo_precmd() {
  # Runs before the next prompt: cursor is one line below the last output line.
  local h; h=$(command tmux display -p -t "$TMUX_PANE" '#{history_size} #{cursor_y}' 2>/dev/null) || return 0
  command tmux set -p -t "$TMUX_PANE" @cmd_end $(( ${h% *} + ${h#* } - 1 )) 2>/dev/null
}
add-zsh-hook preexec _tlo_preexec
add-zsh-hook precmd  _tlo_precmd
