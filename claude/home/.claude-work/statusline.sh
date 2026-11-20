#!/bin/bash
# Work-account status line: an unmistakable WORK tag so a tmux pane is never ambiguous, the session
# badges (~/.claude/statusline-badge.sh, shared with the personal line), then the shared renderer.
input=$(cat)
badges=$(printf '%s' "$input" | "$HOME/.claude/statusline-badge.sh")
line=$(printf '%s' "$input" | "$HOME/.claude/statusline.sh")
printf ' \033[1;48;2;70;50;61;38;2;243;139;168m WORK \033[0m %s%s\n' "$badges" "$line"
