#!/usr/bin/env python3
"""guard-instruction-size.py — PreToolUse (Edit|Write|MultiEdit), both accounts.

Keeps every always-loaded instruction file short (CLAUDE.md, CLAUDE.local.md, AGENTS.md,
GEMINI.md): an edit that would take one past CAP lines is refused, unless it shrinks the file.
A file already over the cap can still be trimmed. Detail belongs in a skill or a path-scoped rule,
which load only when needed. Override the cap with INSTRUCTION_FILE_CAP.
"""
import json, os, sys

CAP = int(os.environ.get("INSTRUCTION_FILE_CAP", "200"))
NAMES = {"CLAUDE.md", "CLAUDE.local.md", "AGENTS.md", "GEMINI.md"}

def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    ti = data.get("tool_input") or {}
    path = ti.get("file_path") or ""
    if data.get("tool_name") not in ("Edit", "Write", "MultiEdit") or os.path.basename(path) not in NAMES:
        return
    try:
        cur = open(path, encoding="utf-8").read()
    except OSError:
        cur = ""
    if "content" in ti:
        new = ti["content"]
    else:
        new = cur
        for e in ti.get("edits") or [ti]:
            old, rep = e.get("old_string", ""), e.get("new_string", "")
            new = new.replace(old, rep) if e.get("replace_all") else new.replace(old, rep, 1)
    before, after = len(cur.splitlines()), len(new.splitlines())
    if after > CAP and after > before:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "permissionDecision": "deny",
            "permissionDecisionReason":
                f"{os.path.basename(path)} would grow from {before} to {after} lines; instruction files "
                f"stay at or under {CAP}. Move the workflow or detail into a skill "
                "(skills/<name>/SKILL.md) or a path-scoped rule and leave a one-line pointer here, "
                "or trim enough in the same edit that the file doesn't grow."}}))

main()
