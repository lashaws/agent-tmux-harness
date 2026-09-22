#!/bin/bash
# Claude Code status line — single line (multi-line output is NOT rendered):
#   cwd | model · effort | 5h bar · 7d bar · ctx bar
input=$(cat)

WIDTH=6          # blocks per bar — raise for wider terminals
SHOW_RESETS=1    # 1 = show ↻reset hints, 0 = hide for a tighter line

dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty')
model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // empty')

# Effort: prefer session value if the harness provides it, else the saved default
effort=$(printf '%s' "$input" | jq -r '.effort.level // .model.effort // .effort_level // empty')
if [ -z "$effort" ]; then
  effort=$(jq -r '.effortLevel // "default"' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" 2>/dev/null)
fi

ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
h5=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
d7=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
h5_reset=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
d7_reset=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# bar <label> <percent> <reset-hint>
bar() {
  local label="$1" pct="$2" hint="$3"
  local n=${pct%%.*}
  [ -z "$n" ] && return
  local filled=$(( (n * WIDTH + 50) / 100 ))
  [ "$filled" -lt 0 ] && filled=0
  # any usage shows at least one block; only a true 100% shows a full bar
  [ "$n" -gt 0 ] && [ "$filled" -eq 0 ] && filled=1
  [ "$n" -lt 100 ] && [ "$filled" -ge "$WIDTH" ] && filled=$(( WIDTH - 1 ))
  [ "$filled" -gt "$WIDTH" ] && filled=$WIDTH

  local color
  if   [ "$n" -ge 80 ]; then color=$'\033[31m'   # red
  elif [ "$n" -ge 50 ]; then color=$'\033[33m'   # yellow
  else                       color=$'\033[32m'   # green
  fi

  local f e i
  for ((i=0; i<filled; i++)); do f+="█"; done
  for ((i=filled; i<WIDTH; i++)); do e+="░"; done

  printf '\033[2m%s\033[0m %s%s\033[0m\033[2;90m%s\033[0m %s%d%%\033[0m' \
    "$label" "$color" "$f" "$e" "$color" "$n"
  # NB: must not end on a failed test — Claude Code drops the status line
  # entirely if the command exits non-zero.
  if [ -n "$hint" ]; then
    printf '\033[2m%s\033[0m' "$hint"
  fi
  return 0
}

# Shorten $HOME to ~
dir="${dir/#$HOME/~}"

# muted teal path | yellow model | dim effort  — the original line, unchanged
printf '\033[38;5;73m%s\033[0m \033[2m|\033[0m \033[33m%s\033[0m \033[2m· %s\033[0m' \
  "$dir" "$model" "$effort"

sep=" \033[2m|\033[0m "
if [ -n "$h5" ]; then
  hint=""
  [ "$SHOW_RESETS" = 1 ] && [ -n "$h5_reset" ] && \
    hint=" ↻$(date -r "$h5_reset" +%-I%p 2>/dev/null | tr 'APM' 'apm')"
  printf "$sep"; bar "5h" "$h5" "$hint"; sep=" \033[2m·\033[0m "
fi
if [ -n "$d7" ]; then
  hint=""
  [ "$SHOW_RESETS" = 1 ] && [ -n "$d7_reset" ] && \
    hint=" ↻$(date -r "$d7_reset" +%a 2>/dev/null)"
  printf "$sep"; bar "7d" "$d7" "$hint"; sep=" \033[2m·\033[0m "
fi
if [ -n "$ctx" ]; then
  printf "$sep"; bar "ctx" "$ctx" ""
fi

exit 0
