#!/bin/bash
# Session badges for both status lines (~/.claude/statusline-personal.sh, ~/.claude-work/statusline.sh).
# Reads the status-line JSON on stdin; prints each badge followed by one space, or nothing.
#   session state (~/.claude/bin/session-state): 👤 waiting on you · ⏳ running · ⚙ working · ✓ done
#   💤 while a /sleep timer (~/.claude/bin/sleep-mode) is alive
input=$(cat)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty')
if [ -n "$transcript" ]; then
  s=$("$HOME/.claude/bin/session-state" "$transcript" 2>/dev/null)
  case "$s" in
    "👤"*) color='1;48;5;208;38;5;232' ;;
    "⏳"*) color='1;48;5;97;38;5;231' ;;
    "⚙"*) color='1;48;5;25;38;5;231' ;;
    *) color='1;48;5;22;38;5;231' ;;
  esac
  [ -n "$s" ] && printf '\033[%sm %s \033[0m ' "$color" "$s"
fi
sched="${SLEEP_MODE_HOME:-$HOME/.claude/sleep}/schedule.json"
if [ -f "$sched" ]; then
  z=$(jq -r 'select(.pid) | "\(.pid) \(if .mode=="time" then .label else "when done" end)"' "$sched" 2>/dev/null)
  if [ -n "$z" ] && kill -0 "${z%% *}" 2>/dev/null; then
    printf '\033[1;48;5;54;38;5;231m 💤 %s \033[0m ' "${z#* }"
  fi
fi
exit 0
