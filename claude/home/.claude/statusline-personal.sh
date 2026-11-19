#!/bin/bash
# Personal-account status line: the shared renderer (~/.claude/statusline.sh, also used by
# ~/.claude-work/statusline.sh) plus a badge for the session state (~/.claude/bin/session-state:
# running background work, waiting on Lashaw, or done). Kept out of statusline.sh itself so the
# work line, which adds its own badge, doesn't show two.
input=$(cat)
line=$(printf '%s' "$input" | "$HOME/.claude/statusline.sh")
state=""
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty')
if [ -n "$transcript" ]; then
  s=$("$HOME/.claude/bin/session-state" "$transcript" 2>/dev/null)
  case "$s" in
    "⏳"*) color='1;48;5;97;38;5;231' ;;
    "⚙"*) color='1;48;5;25;38;5;231' ;;
    "👤"*) color='1;48;5;208;38;5;232' ;;
    *) color='1;48;5;22;38;5;231' ;;
  esac
  [ -n "$s" ] && state=$(printf '\033[%sm %s \033[0m ' "$color" "$s")
fi
# /sleep scheduled (~/.claude/bin/sleep-mode): show when, while its timer is alive
sched="${SLEEP_MODE_HOME:-$HOME/.claude/sleep}/schedule.json"
if [ -f "$sched" ]; then
  z=$(jq -r 'select(.pid) | "\(.pid) \(if .mode=="time" then .label else "when done" end)"' "$sched" 2>/dev/null)
  if [ -n "$z" ] && kill -0 "${z%% *}" 2>/dev/null; then
    state="$state$(printf '\033[1;48;5;54;38;5;231m 💤 %s \033[0m ' "${z#* }")"
  fi
fi
printf '%s%s\n' "$state" "$line"
exit 0
