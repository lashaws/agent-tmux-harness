#!/usr/bin/env bash
# A subagent may not finish while background tasks it started are still running. One rule, two exits:
#   SubagentStop (all agents): blocks the stop once.
#   PreToolUse, matcher SubagentHandback: denies the hand-back once.
#
# Why: a verifier reported its result and left a wait loop running for 1.5 hours (#4961, 2026-11-09,
# task bd5zpca6l: started by a foreground call moved to the background). Then on 2026-11-24 an
# implementer handed back with SubagentHandback while three watchers ran. Handing back is not a stop,
# so the SubagentStop check never ran; Claude Code held the report waiting on watchers that could
# never end (`while pgrep -f "shoot.mjs 8093"` matches its own shell), and the agent showed as
# running in Lashaw's status line for five hours.
#
# A task is open when the subagent's transcript shows it started (`run_in_background`, or a
# foreground call that hit its timeout) with no end record (a `<task-notification>` with status
# completed/failed/killed/stopped, or a successful TaskStop). The decision comes from structured
# transcript entries only, via `session-state open-tasks`; text that merely quotes those phrases (a
# fixture, a report, a pasted log) counts for nothing (2026-11-19: quoted ids bFAKE, bQUOTE, bSIDE
# blocked a hand-back).
#
# Never blocks twice: a stop with stop_hook_active true, or the same hand-back retried with the same
# task ids, goes through, so a wrong reading can never trap an agent.
# Fails open: no jq, no transcript, an unreadable transcript or a parse error all allow it.
# Claude-only: Gemini CLI has no SubagentStop event.
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
field() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }
event=$(field .hook_event_name)
agent=$(field .agent_id)

if [ "$event" = "PreToolUse" ]; then
  [ -n "$agent" ] || exit 0   # the main session's hand-back is never ours to judge
  # PreToolUse carries no agent_transcript_path: subagents live beside the main transcript.
  main=$(field .transcript_path); sid=$(field .session_id); main="${main/#\~/$HOME}"
  [ -n "$main" ] && [ -n "$sid" ] || exit 0
  tp="$(dirname "$main")/$sid/subagents/agent-$agent.jsonl"
else
  [ "$(field .stop_hook_active)" = "true" ] && exit 0
  tp=$(field .agent_transcript_path); tp="${tp/#\~/$HOME}"
fi
[ -f "$tp" ] || exit 0

pending=$("${SESSION_STATE:-$HOME/.claude/bin/session-state}" open-tasks "$tp" 2>/dev/null | sort | tr '\n' ' ') || exit 0
pending="${pending% }"
[ -n "$pending" ] || exit 0
reason="Background tasks you started are still running: $pending. Stop each with TaskStop if its result is no longer needed (and kill any server or process you started with & or nohup), or wait for it, then report again."

if [ "$event" = "PreToolUse" ]; then
  mark="${TMPDIR:-/tmp}/claude-handback-guard-$(printf '%s %s' "$agent" "$pending" | shasum | cut -c1-16)"
  [ -e "$mark" ] && exit 0
  : > "$mark"
  jq -n --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
else
  jq -n --arg r "$reason" '{decision: "block", reason: $r}'
fi
