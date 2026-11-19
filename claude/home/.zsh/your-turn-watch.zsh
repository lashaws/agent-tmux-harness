# ~/.zsh/your-turn-watch.zsh — notice when Lashaw runs a command an agent handed
# over ("Your turn" item) and tell the your-turn list: exit code plus captured
# output, so the agent (blocked in `your-turn wait`) is woken without being told.
#
# Output is redacted by `ran`; commands on its secret list are never captured.
# Nothing here touches the command: preexec only stashes the line when some open
# item exists (pure zsh, no fork); the match, capture and recording happen in
# precmd, after the command has finished. Every failure is silent.
#
# Needs tmux-last-output.zsh sourced first (it stamps @cmd_start/@cmd_end); outside
# tmux only the exit code is recorded. YOUR_TURN_CONFIGS (colon-separated) overrides
# the two config dirs, for tests.
autoload -Uz add-zsh-hook

typeset -g _yt_cmd= _yt_status=
typeset -ga _yt_cfgs
_yt_cfgs=( ${(s.:.)YOUR_TURN_CONFIGS:-$HOME/.claude:$HOME/.claude-work} )

_yt_preexec() {
  _yt_cmd=
  local cfg f body first=${${(z)1}[1]}
  [[ -n $first ]] || return 0
  for cfg in $_yt_cfgs; do
    for f in $cfg/pending/*.jsonl(N); do
      body=$(<$f) || continue
      # an open item that mentions the command's first word: worth asking python
      if [[ $body == *'"status":"open"'* && $body == *"$first"* ]]; then
        _yt_cmd=$1
        return 0
      fi
    done
  done
  return 0
}

_yt_precmd_first() {  # must run before any other precmd: they overwrite $?
  _yt_status=$?
  return $_yt_status
}

_yt_precmd() {
  [[ -n $_yt_cmd ]] || return 0
  local cmd=$_yt_cmd status_=$_yt_status
  _yt_cmd=
  {
    local tool=$HOME/.claude/bin/your-turn matches line cfg id pos hist s e out= skip=
    matches=$(YOUR_TURN_CONFIGS=${(j.:.)_yt_cfgs} command $tool match "$cmd") || return 0
    [[ -n $matches ]] || return 0
    # A command that prints secrets is never captured: decided here, so nothing touches disk.
    command $tool secret-cmd "$cmd" && skip=1
    if [[ -z $skip && -n $TMUX && -n $TMUX_PANE ]]; then
      pos=$(command tmux display -p -t "$TMUX_PANE" '#{@cmd_start} #{@cmd_end} #{history_size}') || pos=
      s=${${(z)pos}[1]} e=${${(z)pos}[2]} hist=${${(z)pos}[3]}
      if [[ $s == <-> && $e == <-> && $hist == <-> && $e -ge $s ]]; then
        # held in memory and fed to `ran` on stdin, which redacts before writing: no raw temp file
        out=$(command tmux capture-pane -p -J -t "$TMUX_PANE" -S $(( s - hist )) -E $(( e - hist ))) || out=
      fi
    fi
    for line in ${(f)matches}; do
      cfg=${line%%$'\t'*} id=${line#*$'\t'}
      if [[ -n $skip ]]; then
        CLAUDE_CONFIG_DIR=$cfg command $tool ran $id $status_ --no-output >/dev/null
      elif [[ -n $out ]]; then
        CLAUDE_CONFIG_DIR=$cfg command $tool ran $id $status_ --out - >/dev/null <<<$out
      else
        CLAUDE_CONFIG_DIR=$cfg command $tool ran $id $status_ >/dev/null
      fi
    done
  } 2>/dev/null
  return 0
}

precmd_functions=( _yt_precmd_first ${precmd_functions:#_yt_precmd_first} )
add-zsh-hook preexec _yt_preexec
add-zsh-hook precmd _yt_precmd
