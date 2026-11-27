#!/bin/bash
# stamp-app-launch.sh — PreToolUse hook on Bash (personal and work accounts). Never blocks.
# When an agent's Bash command may open or activate a GUI app, record the time so focus-guard
# (~/.claude/bin/focus-guard) treats apps launched in the next few seconds as agent-driven.
mkdir -p "$HOME/.claude/local/focus-guard"; input=$(cat)
cmd=$(printf '%s' "$input" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("command","") if d.get("tool_name")=="Bash" else "")' 2>/dev/null)
[ -z "$cmd" ] && exit 0
if printf '%s' "$cmd" | grep -Eq '(^|[;&|( ]|/usr/bin/)open( |$)|\.app\b|osascript|electron|playwright|puppeteer|agent-browser|npm (run )?(dev|start)|npx electron|Chrome'; then
  /bin/date +%s > "$HOME/.claude/local/focus-guard/agent-launch-at"
fi
exit 0
