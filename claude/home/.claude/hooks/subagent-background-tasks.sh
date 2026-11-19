#!/usr/bin/env bash
# SubagentStop hook (all agents) for #4961: a subagent may not finish while background shell tasks
# it started are still running.
#
# Refuses (blocks the stop once) when the subagent's transcript shows a background task with no end
# record: started by `run_in_background` or by a foreground call that hit its timeout (moved to the
# background), and never ended by a `<task-notification>` with status completed/failed/killed/stopped
# or by a successful TaskStop. Why: a verifier reported its result and left a wait loop running for
# 1.5 hours (the 2026-11-09 case, task bd5zpca6l: started by a call moved to the background).
# The decision comes from structured transcript entries only, via `session-state open-tasks`; text
# that merely quotes those phrases (a fixture, a report, a pasted log) counts for nothing
# (2026-11-19: quoted ids bFAKE, bQUOTE, bSIDE blocked a hand-back).
# Recover: stop each named task with TaskStop if its result is no longer needed, or wait for it,
# then report again.
#
# Never blocks twice: a payload with stop_hook_active true is allowed, so a stuck agent cannot loop.
# Fails open: no jq, an unreadable transcript or a parse error all allow the stop.
# Claude-only: Gemini CLI has no SubagentStop event.
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0
transcript=$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null)
transcript="${transcript/#\~/$HOME}"
[ -f "$transcript" ] || exit 0

pending=$("${SESSION_STATE:-$HOME/.claude/bin/session-state}" open-tasks "$transcript" 2>/dev/null | tr '\n' ' ') || exit 0
pending="${pending% }"
[ -n "$pending" ] || exit 0

jq -n --arg ids "$pending" '{decision: "block", reason: ("Background tasks you started are still running: " + $ids + ". Stop each with TaskStop if its result is no longer needed, or wait for it, then report again.")}'
