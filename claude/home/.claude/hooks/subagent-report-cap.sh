#!/usr/bin/env bash
#
# SubagentStart hook (matcher Explore|general-purpose|Plan) — cap a built-in agent's report length (#4349).
#
# Why: the built-in agents have no definition file to carry the "report under ~60 lines" rule
# from AGENTS.md, so their reports land in the main session at whatever length they choose and
# inflate its context (#3596). This adds the rule to the subagent's own context when it starts.
#
# Never refuses: SubagentStart cannot block, and the input is not read. It prints
# hookSpecificOutput.additionalContext, which Claude Code gives to the subagent.
# Claude Code only: Gemini CLI has no subagent hook, so this is not wired into .gemini/settings.json.

set -uo pipefail

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"Report under 60 lines; put bulk detail in a file and give its path."}}
JSON
