#!/bin/bash
# Work-account status line: delegates to the shared renderer, prefixes an
# unmistakable account tag so a tmux pane is never ambiguous.
input=$(cat)
line=$(printf '%s' "$input" | "$HOME/.claude/statusline.sh")
printf ' \033[1;48;5;208;38;5;232m WORK \033[0m %s\n' "$line"
