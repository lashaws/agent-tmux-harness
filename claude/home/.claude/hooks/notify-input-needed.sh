#!/bin/bash
# Notification hook: show a macOS banner with sound when Claude Code is waiting on you
# (permission prompt, a question, or idle at the prompt). Reads the hook JSON on stdin.
# When commands handed to Lashaw are still open (~/.claude/bin/your-turn), the subtitle
# counts them and the body names the first one. Shared by both accounts: your-turn reads the
# account's list from $CLAUDE_CONFIG_DIR (~/.claude-work for work sessions, else ~/.claude).
input=$(cat)
message=$(jq -r '.message // "Claude Code needs your input"' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
session=$(jq -r '.session_id // empty' <<<"$input")
project=$(basename "${cwd:-$PWD}")
subtitle="$project"

if [ -n "$session" ]; then
  yt="$HOME/.claude/bin/your-turn"
  n=$("$yt" count "$session" 2>/dev/null)
  if [ "${n:-0}" -gt 0 ]; then
    subtitle="$project · $n waiting on you"
    message="Next: $("$yt" first "$session" 2>/dev/null) (repeated at the end of the reply)"
  fi
fi

# Escape backslashes and double quotes for the AppleScript string literals.
esc() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' <<<"$1"; }

osascript -e "display notification \"$(esc "$message")\" with title \"Claude Code\" subtitle \"$(esc "$subtitle")\" sound name \"Glass\""
