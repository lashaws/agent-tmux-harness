#!/bin/bash
# Personal-account status line: session badges (~/.claude/statusline-badge.sh, shared with the work
# line) then the shared renderer (~/.claude/statusline.sh).
input=$(cat)
badges=$(printf '%s' "$input" | "$HOME/.claude/statusline-badge.sh")
line=$(printf '%s' "$input" | "$HOME/.claude/statusline.sh")
printf '%s%s\n' "$badges" "$line"
exit 0
