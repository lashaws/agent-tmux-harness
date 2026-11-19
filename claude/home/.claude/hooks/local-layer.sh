#!/bin/bash
# local-layer.sh — runs this Mac's untracked additions from ~/.claude/local/, which the dotfiles
# harness never captures (rules, guards and env meant for this machine only).
#   local-layer.sh session-start   append ~/.claude/local/env.sh to $CLAUDE_ENV_FILE, which
#                                  Claude Code sources before every Bash command
#   local-layer.sh pre-tool-use    run each executable in ~/.claude/local/hooks/pre-tool-use/;
#                                  the first that prints a decision or exits 2 wins
# Local rules for the model live in ~/.claude/local/rules.md, imported by ~/.claude/CLAUDE.md.
LOCAL="$HOME/.claude/local"
case "${1:-}" in
  session-start)
    if [ -f "$LOCAL/env.sh" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
      cat "$LOCAL/env.sh" >> "$CLAUDE_ENV_FILE"
    fi ;;
  pre-tool-use)
    input=$(cat)
    for g in "$LOCAL/hooks/pre-tool-use/"*; do
      [ -f "$g" ] && [ -x "$g" ] || continue
      out=$(printf '%s' "$input" | "$g"); rc=$?
      [ "$rc" -eq 2 ] && exit 2
      if [ -n "$out" ]; then printf '%s\n' "$out"; exit 0; fi
    done ;;
esac
exit 0
