#!/usr/bin/env python3
"""guard-third-party.py — PreToolUse (Bash|Edit|Write|MultiEdit), both accounts.

Lashaw avoids other companies' MCP servers and packages for security and prefers small,
dependency-free tools we write. This guard does not refuse: it turns these into a permission
prompt so Lashaw decides each one.
  - `claude mcp add…`, an `.mcp.json` edit, or `mcpServers` added to a settings file
  - a package install that names a package (npm/pnpm/yarn/bun add, pip/uv/poetry/cargo/go/gem/pipx)
  - a new dependency in package.json or requirements*.txt
Reinstalling what a lockfile already lists (`npm ci`, `npm install`, `pip install -r …`) passes.
"""
import json, os, re, shlex, sys

def ask(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse", "permissionDecision": "ask",
        "permissionDecisionReason": reason + " Lashaw prefers small tools we write over other "
        "companies' MCP servers and packages; approve only if this one is worth the trust."}}))
    sys.exit(0)

INSTALL = [  # (regex for the command head, label)
    (r"npm\s+(?:install|i|in|add)\b", "npm install"), (r"pnpm\s+(?:add|install|i)\b", "pnpm add"),
    (r"yarn\s+add\b", "yarn add"), (r"bun\s+(?:add|install|i)\b", "bun add"),
    (r"(?:python3?\s+-m\s+)?pip3?\s+install\b", "pip install"), (r"uv\s+pip\s+install\b", "uv pip install"),
    (r"uv\s+add\b", "uv add"), (r"poetry\s+add\b", "poetry add"), (r"cargo\s+add\b", "cargo add"),
    (r"go\s+get\b", "go get"), (r"gem\s+install\b", "gem install"), (r"pipx\s+install\b", "pipx install"),
]
FLAGS_WITH_VALUE = {"-r", "--requirement", "-c", "--constraint", "-e", "--editable", "--prefix",
                    "--target", "-t", "--index-url", "-i", "--extra-index-url", "--registry", "--cwd", "-C"}

def named_packages(rest):
    try:
        toks = shlex.split(rest)
    except ValueError:
        toks = rest.split()
    out, skip = [], False
    for t in toks:
        if skip:
            skip = False; continue
        if t in FLAGS_WITH_VALUE:
            skip = True; continue
        if t.startswith("-") or t.startswith((".", "/", "~")) or "=" in t and t.startswith("--"):
            continue
        out.append(t)
    return out

LEAD = re.compile(r"^(?:(?:sudo|env|command|time|exec)\s+|[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*")

def check_bash(cmd):
    # Only the command at the start of each segment counts, so `echo "npm install x"` or a grep
    # for the words passes; `cd x && npm i y` and `FOO=1 pip install y` are caught.
    for seg in re.split(r"&&|\|\||;|\||\n|\$\(|`", cmd):
        seg = LEAD.sub("", seg.strip().lstrip("({ "))
        if re.match(r"(?:\S*/)?claude\s+mcp\s+add", seg):
            ask("This adds an MCP server (`claude mcp add`).")
        for pat, label in INSTALL:
            m = re.match(r"(?:\S*/)?" + pat + r"(.*)$", seg)
            if m:
                pkgs = named_packages(m.group(1))
                if pkgs:
                    ask(f"This installs a package ({label} {' '.join(pkgs[:4])}).")

def resulting_text(ti, path):
    try:
        cur = open(path, encoding="utf-8").read()
    except OSError:
        cur = ""
    if "content" in ti:
        return cur, ti["content"]
    new = cur
    for e in ti.get("edits") or [ti]:
        old, rep = e.get("old_string", ""), e.get("new_string", "")
        new = new.replace(old, rep) if e.get("replace_all") else new.replace(old, rep, 1)
    return cur, new

def npm_deps(text):
    try:
        d = json.loads(text)
    except ValueError:
        return None
    deps = {}
    for k in ("dependencies", "devDependencies", "peerDependencies", "optionalDependencies"):
        deps.update((d.get(k) or {}) if isinstance(d.get(k), dict) else {})
    return {n for n, v in deps.items()
            if not str(v).startswith(("workspace:", "file:", "link:", "portal:"))}

def req_names(text):
    names = set()
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if line and not line.startswith(("-", ".", "/")):
            names.add(re.split(r"[<>=!~\[;@ ]", line, 1)[0].lower())
    return names

def check_edit(ti):
    path = ti.get("file_path") or ""
    base = os.path.basename(path)
    if base == ".mcp.json":
        ask(f"This edits {base}, which defines MCP servers.")
    cur, new = resulting_text(ti, path)
    if base in ("settings.json", "settings.local.json", ".claude.json", "claude_desktop_config.json") \
            and new.count('"mcpServers"') > cur.count('"mcpServers"'):
        ask(f"This adds an `mcpServers` block to {base}.")
    if base == "package.json":
        before, after = npm_deps(cur) or set(), npm_deps(new)
        if after is not None and after - before:
            ask(f"This adds dependencies to package.json: {', '.join(sorted(after - before)[:5])}.")
    if re.fullmatch(r"requirements.*\.txt", base):
        added = req_names(new) - req_names(cur)
        if added:
            ask(f"This adds Python requirements: {', '.join(sorted(added)[:5])}.")

def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    ti = data.get("tool_input") or {}
    if data.get("tool_name") == "Bash":
        check_bash(ti.get("command") or "")
    elif data.get("tool_name") in ("Edit", "Write", "MultiEdit"):
        check_edit(ti)

main()
