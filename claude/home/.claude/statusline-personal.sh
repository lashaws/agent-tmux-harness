#!/bin/bash
# Personal-account status line: session badges (~/.claude/statusline-badge.sh, shared with the work
# line) then the shared renderer (~/.claude/statusline.sh). Records rate limits for
# claude-account and tags the line with the account name when 2+ accounts are listed.
input=$(cat)
acct="$HOME/.claude/bin/claude-account"
printf '%s' "$input" | "$acct" record >/dev/null 2>&1 &
tag=""
name=$("$acct" current 2>/dev/null)
if [ -n "$name" ] && [ "$(grep -cvE '^[[:space:]]*(#|$)' "$HOME/.claude/local/accounts.tsv" 2>/dev/null)" -ge 2 ]; then
  tag=$(printf '\033[2m[%s]\033[0m ' "$name")
fi
badges=$(printf '%s' "$input" | "$HOME/.claude/statusline-badge.sh")
line=$(printf '%s' "$input" | "$HOME/.claude/statusline.sh")
printf '%s%s%s\n' "$tag" "$badges" "$line"
exit 0
