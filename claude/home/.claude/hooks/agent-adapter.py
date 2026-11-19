#!/usr/bin/env python3
"""agent-adapter.py — run Lashaw's Claude Code guards from Codex and Gemini hooks.

  agent-adapter.py codex  pre-tool   Codex PreToolUse (tool Bash or apply_patch)
  agent-adapter.py codex  stop       Codex Stop
  agent-adapter.py gemini pre-tool   Gemini BeforeTool (run_shell_command, write_file, replace)
  agent-adapter.py gemini stop       Gemini AfterAgent

Each payload is turned into the Claude Code shape (Bash / Write / Edit / MultiEdit, or
last_assistant_message), the same guards run, and their decision is written back in the
caller's format. Codex and Gemini have no permission prompt for hooks, so a guard's "ask"
becomes a refusal whose reason tells the agent to get Lashaw's approval in chat first.
"""
import json, os, re, subprocess, sys

H = os.path.expanduser("~/.claude/hooks")
PRE = [[f"{H}/guard-third-party.py"], [f"{H}/guard-instruction-size.py"], [f"{H}/local-layer.sh", "pre-tool-use"]]
STOP = [[f"{H}/stop-handback-guard.py"]]

def patch_to_claude(patch):
    """Codex apply_patch text -> list of Claude-shaped Write/MultiEdit tool calls."""
    calls, cur, hunk = [], None, None
    def flush_hunk():
        if cur is not None and hunk is not None and cur["tool_name"] == "MultiEdit" and (hunk[0] or hunk[1]):
            cur["tool_input"]["edits"].append({"old_string": "\n".join(hunk[0]), "new_string": "\n".join(hunk[1])})
    for line in patch.splitlines():
        m = re.match(r"\*\*\* (Add|Update|Delete) File: (.+)$", line)
        if m:
            flush_hunk(); hunk = None
            kind, path = m.group(1), m.group(2).strip()
            if kind == "Add":
                cur = {"tool_name": "Write", "tool_input": {"file_path": path, "content": ""}}
            elif kind == "Update":
                cur = {"tool_name": "MultiEdit", "tool_input": {"file_path": path, "edits": []}}; hunk = ([], [])
            else:
                cur = None
            if cur: calls.append(cur)
            continue
        if cur is None or line.startswith("*** "):
            continue
        if cur["tool_name"] == "Write":
            if line.startswith("+"):
                c = cur["tool_input"]["content"]
                cur["tool_input"]["content"] = c + ("\n" if c else "") + line[1:]
        else:
            if line.startswith("@@"):
                flush_hunk(); hunk = ([], [])
            elif line.startswith("-"):
                hunk[0].append(line[1:])
            elif line.startswith("+"):
                hunk[1].append(line[1:])
            elif line.startswith(" "):
                hunk[0].append(line[1:]); hunk[1].append(line[1:])
    flush_hunk()
    return calls

def normalize(agent, event, data):
    if event == "stop":
        msg = data.get("last_assistant_message") if agent == "codex" else data.get("prompt_response")
        return [{"last_assistant_message": msg or "", "stop_hook_active": bool(data.get("stop_hook_active"))}]
    name, ti = data.get("tool_name"), data.get("tool_input") or {}
    base = {"cwd": data.get("cwd") or os.getcwd()}
    if name in ("Bash", "run_shell_command", "shell", "exec_command"):
        return [dict(base, tool_name="Bash", tool_input={"command": ti.get("command") or ti.get("cmd") or ""})]
    if name == "apply_patch":
        return [dict(base, **c) for c in patch_to_claude(ti.get("command") or ti.get("patch") or ti.get("input") or "")]
    if name == "write_file":
        return [dict(base, tool_name="Write", tool_input={"file_path": ti.get("file_path"), "content": ti.get("content", "")})]
    if name == "replace":
        return [dict(base, tool_name="Edit", tool_input={"file_path": ti.get("file_path"), "old_string": ti.get("old_string", ""),
                                                          "new_string": ti.get("new_string", ""), "replace_all": bool(ti.get("allow_multiple"))})]
    return []

def run_guards(guards, payload):
    """First guard that objects wins: returns (kind, reason) or None."""
    for g in guards:
        r = subprocess.run(g, input=json.dumps(payload), capture_output=True, text=True)
        if r.returncode == 2:
            return ("deny", r.stderr.strip())
        out = r.stdout.strip()
        if not out:
            continue
        try:
            d = json.loads(out.splitlines()[-1])
        except ValueError:
            continue
        hso = d.get("hookSpecificOutput") or {}
        if hso.get("permissionDecision") in ("deny", "ask"):
            reason = hso.get("permissionDecisionReason", "")
            if hso["permissionDecision"] == "ask":
                reason = "Needs Lashaw's approval: " + reason + " Ask Lashaw in chat and wait for an explicit yes before retrying."
            return ("deny", reason)
        if d.get("decision") == "block":
            return ("block", d.get("reason", ""))
    return None

def main():
    agent, event = sys.argv[1], sys.argv[2]
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    guards = STOP if event == "stop" else PRE
    for payload in normalize(agent, event, data):
        hit = run_guards(guards, payload)
        if not hit:
            continue
        kind, reason = hit
        if agent == "gemini":
            print(json.dumps({"decision": "deny", "reason": reason}))
        elif event == "stop":
            print(json.dumps({"decision": "block", "reason": reason}))
        else:
            print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                  "permissionDecision": "deny", "permissionDecisionReason": reason}}))
        return

main()
