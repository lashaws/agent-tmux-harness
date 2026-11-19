#!/usr/bin/env python3
"""stop-handback-guard.py — Stop hook, both accounts.

Lashaw has typed "complete this autonomously" in dozens of prompts. This enforces it: a reply
whose ending hands work back ("want me to…?", "should I proceed?", "let me know if you'd like…",
a "Next steps" list for Lashaw) is blocked once, so the agent does the work instead, or names
the reason the step is Lashaw's and stops again (the second stop passes: stop_hook_active).
A real hand-over (`**Your turn**`, `Still waiting on you`) and a `Next:` line are not handbacks.
"""
import json, re, sys

PATTERNS = [
    r"\b(?:do you )?want me to\b[^.?!\n]*\?",
    r"\bwould you like me to\b",
    r"\bshall i\b[^.?!\n]*\?",
    r"\bshould i (?:proceed|go ahead|continue|start|do|implement|apply|run|make|create|open|fix|add|update|build)\b[^.?!\n]*\?",
    r"\blet me know if you(?:'d| would)? (?:like|want)\b",
    r"\bif you(?:'d| would) like,? i (?:can|could|will)\b",
    r"\bi can also\b[^.\n]*\bif you\b",
    r"\bhappy to\b[^.\n]*\bif you\b",
    r"(?m)^\s*(?:#+\s*|\*\*)?next steps\b",
    r"\byou might (?:also|want to)\b",
    r"\bone more thing\b",
]

def ending(msg):
    msg = re.sub(r"```.*?```", " ", msg, flags=re.S)          # code blocks
    msg = re.sub(r"`[^`\n]*`", " ", msg)                       # inline code
    msg = re.sub(r"[\"“][^\"”\n]{0,200}[\"”]", " ", msg)       # quoted phrases
    paras = [p for p in re.split(r"\n\s*\n", msg) if p.strip()]
    return "\n\n".join(paras[-2:])[-700:]

def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if data.get("stop_hook_active"):
        return
    msg = data.get("last_assistant_message") or ""
    if not msg or "**Your turn**" in msg or "Still waiting on you" in msg:
        return
    tail = ending(msg)
    for p in PATTERNS:
        m = re.search(p, tail, re.I)
        if m:
            print(json.dumps({"decision": "block", "reason":
                f"Your reply ends by handing work back (\"{m.group(0).strip()[:80]}\"). Lashaw's standing "
                "rule: finish the goal, never end with an offer or a to-do list for them. If the step is in "
                "scope, do it now. If it truly needs Lashaw (a decision reserved to them, something "
                "destructive or irreversible, or a real permission block), say which in one line and end "
                "again; this check runs once per stop."}))
            return

main()
