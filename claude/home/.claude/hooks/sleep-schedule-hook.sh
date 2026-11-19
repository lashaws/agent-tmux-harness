#!/bin/bash
# PostToolUse / UserPromptSubmit hook for /sleep: exits at once unless a schedule exists, so the cost on
# every tool call is one stat. Otherwise sleep-mode injects the away note (once per session) and, from
# T-20 minutes before a timed sleep, the wrap-up warning (once per session).
[ -f "${SLEEP_MODE_HOME:-$HOME/.claude/sleep}/schedule.json" ] || exit 0
exec "$HOME/.claude/bin/sleep-mode" hook
