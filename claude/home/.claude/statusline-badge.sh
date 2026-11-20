#!/bin/bash
# Session badges for both status lines (~/.claude/statusline-personal.sh, ~/.claude-work/statusline.sh).
# Reads the status-line JSON on stdin; prints each badge followed by one space, or nothing.
#   session state (~/.claude/bin/session-state): 👤 waiting on you · ⏳ running · ⚙ working · ✓ done
#   💤 while a /sleep timer (~/.claude/bin/sleep-mode) is alive
# Palette "only you get a pill" (Catppuccin Mocha, truecolor): 👤 is the one solid pill; ⏳ and ⚙ are
# tinted chips; ✓ done is quiet text. A mixed state ("👤 … · ⏳ …") is split so each part keeps its color.
WAIT='1;48;2;250;179;135;38;2;30;30;46'   # peach pill, dark text
RUN='48;2;57;53;74;38;2;203;166;247'      # mauve on a mauve tint
WORK='48;2;44;56;75;38;2;137;180;250'     # blue on a blue tint
DONE='2;38;2;166;227;161'                 # dim green text
SLEEP='38;2;147;153;178'                  # overlay gray text

chip() { [ -n "$2" ] && printf '\033[%sm %s \033[0m ' "$1" "$2"; return 0; }

input=$(cat)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty')
if [ -n "$transcript" ]; then
  s=$("$HOME/.claude/bin/session-state" "$transcript" 2>/dev/null)
  case "$s" in
    "👤"*)
      rest=""
      case "$s" in
        *" · ⏳"*) rest="⏳${s#* · ⏳}"; s="${s%% · ⏳*}" ;;
        *" · ⚙"*) rest="⚙${s#* · ⚙}"; s="${s%% · ⚙*}" ;;
      esac
      chip "$WAIT" "$s"
      case "$rest" in "⏳"*) chip "$RUN" "$rest" ;; "⚙"*) chip "$WORK" "$rest" ;; esac
      ;;
    "⏳"*) chip "$RUN" "$s" ;;
    "⚙"*) chip "$WORK" "$s" ;;
    *) chip "$DONE" "$s" ;;
  esac
fi
sched="${SLEEP_MODE_HOME:-$HOME/.claude/sleep}/schedule.json"
if [ -f "$sched" ]; then
  z=$(jq -r 'select(.pid) | "\(.pid) \(if .mode=="time" then .label else "when done" end)"' "$sched" 2>/dev/null)
  if [ -n "$z" ] && kill -0 "${z%% *}" 2>/dev/null; then
    chip "$SLEEP" "💤 ${z#* }"
  fi
fi
exit 0
