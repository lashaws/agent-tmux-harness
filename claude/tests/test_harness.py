"""Behaviour tests for the Claude Code harness scripts (~/.claude/bin/your-turn, session-state).

Run: python3 -I ~/dotfiles/claude/tests/test_harness.py   (harness.sh capture runs it first)
Everything happens in a throwaway config dir; the live ~/.claude and ~/.claude-work are never touched.
"""
import json, os, subprocess, sys, tempfile, time
from importlib.machinery import SourceFileLoader
from pathlib import Path

B = Path(os.environ.get("HARNESS_BIN") or Path.home() / ".claude/bin")
tmp = Path(tempfile.mkdtemp(prefix="harness-test-"))
os.environ.update(CLAUDE_CONFIG_DIR=str(tmp), SESSION_STATE_CONFIGS=str(tmp), YOUR_TURN_CONFIGS=str(tmp), SESSION_STATE_DRY_RUN="1")
yt = SourceFileLoader("yt", str(B / "your-turn")).load_module()
ss = SourceFileLoader("ss", str(B / "session-state")).load_module()
fails = 0


def check(name, got, want):
    global fails
    ok = want(got) if callable(want) else got == want
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f"\n   got: {got!r}\n  want: {want!r}"))
    fails += not ok


def item(iid, cmd, status="open", note=""):
    return {"id": iid, "status": status, "cmd": cmd, "note": note, "at": "x"}


def write_items(session, items):
    (tmp / "pending").mkdir(exist_ok=True)
    (tmp / "pending" / f"{session}.jsonl").write_text("".join(json.dumps(i, separators=(",", ":")) + "\n" for i in items))


# --- status token: 👤 leads, waiter shells never count
st = {"tasks": {}, "questions": []}
check("token: done", ss.token(st, 0), "✓ done")
check("token: waiting", ss.token(st, 2), "👤 2 waiting on you")
check("token: waiting + working", ss.token(st, 1, True), "👤 1 waiting on you · ⚙ working")
st2 = {"tasks": {"a": {"kind": "shell", "running": True}, "w": {"kind": "waiter", "running": True}}, "questions": []}
check("token: waiter not counted", ss.token(st2, 0), "⏳ 1 shell")
check("token: waiting leads running", ss.token(st2, 1), "👤 1 waiting on you · ⏳ 1 shell")
check("token: lone waiter is done", ss.token({"tasks": {"w": {"kind": "waiter", "running": True}}, "questions": []}, 0), "✓ done")

# --- transcript parse: both wait forms are waiters, other shells are shells
proj = tmp / "projects" / "p"
proj.mkdir(parents=True)
sid = "sess-1"
tr = proj / f"{sid}.jsonl"


def a_tool(tid, cmd):
    return {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": tid, "name": "Bash", "input": {"command": cmd, "run_in_background": True}}]}}


def u_res(tid, bgid):
    return {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": tid, "content": f"Command running in background with ID: {bgid}"}]},
            "toolUseResult": {"backgroundTaskId": bgid}}


lines = [{"type": "user", "message": {"content": "Stop hook feedback: Stop blocked once"}},
         {"type": "user", "message": {"content": "please fix the status line for me"}},
         a_tool("t1", "~/.claude/bin/your-turn wait abc123"), u_res("t1", "bg1"),
         a_tool("t3", "~/.claude/bin/your-turn wait --session"), u_res("t3", "bg3"),
         a_tool("t2", "npm run build"), u_res("t2", "bg2")]
tr.write_text("".join(json.dumps(x) + "\n" for x in lines))
write_items(sid, [item("abc123", "gcloud auth login")])
check("parse: waiters apart from shells", ss.state_of(str(tr), idle=True)[0], "👤 1 waiting on you · ⏳ 1 shell")
sf = tmp / "session-state" / f"{sid}.json"
stj = json.loads(sf.read_text())
check("parse: first prompt skips hook feedback", stj["first"], "please fix the status line for me")
stj.pop("v"); stj["tasks"] = {"bg1": {"kind": "shell", "running": True}}
sf.write_text(json.dumps(stj))
check("parse: pre-v2 cache is reparsed", ss.state_of(str(tr), idle=True)[0], "👤 1 waiting on you · ⏳ 1 shell")

# --- Stop gates
it = item("abc123", "gcloud auth login", note="signs in")
d = {"session_id": "s"}
reprinted = "Done.\n\n**Still waiting on you**\n1. signs in\n```bash\ngcloud auth login\n```"
check("gate: open command missing blocks", "Still waiting on you" in yt.gate_reason(d, "All done.", [], [it]), True)
check("gate: open command shown passes", yt.gate_reason(d, reprinted, [], [it]), "")
check("gate: nothing open passes", yt.gate_reason(d, "All done.", [], []), "")
check("gate: stop_hook_active passes", yt.gate_reason({**d, "stop_hook_active": True}, "All done.", [], [it]), "")
check("gate: subagent passes", yt.gate_reason({**d, "agent_id": "x"}, "All done.", [], [it]), "")
check("gate: pointer phrases no longer block", yt.gate_reason(d, "Run the command in my last reply. See above.", [], []), "")
handover = "**Your turn** — x\nWhy yours: sign-in\n```bash\ngcloud auth login\n```"
r = yt.gate_reason(d, handover, [it], [it])
check("gate: new item without watcher asks for wait --session", "wait --session" in r and "no watcher" in r, True)
check("gate: missing Why yours blocks", "Why yours" in yt.gate_reason(d, "**Your turn** — x\n```bash\nls\n```", [], []), True)
(tmp / "pending").mkdir(exist_ok=True)
yt.waiter_path("s").write_text(str(os.getpid()))
check("gate: new item with live watcher passes", yt.gate_reason(d, handover, [it], [it]), "")
yt.waiter_path("s").write_text("999999")
check("gate: dead watcher pid does not count", "no watcher" in yt.gate_reason(d, handover, [it], [it]), True)
yt.waiter_path("s").unlink()
check("extract: Why yours stays out of the note",
      yt.extract("**Your turn** — x\nWhy yours: no push asked.\n\nPushes it.\n\n```bash\ngit push\n```"),
      [{"cmd": "git push", "note": "Pushes it.", "unblocks": "x"}])

# --- prompt hook is the item list only
write_items("p1", [item("aa11bb", "gcloud auth login", note="signs you in")])
out = subprocess.run([str(B / "your-turn"), "prompt"], input='{"session_id":"p1"}', capture_output=True, text=True).stdout.strip().splitlines()
check("prompt hook: header + one line per item", len(out), 2)
check("prompt hook: item line", out[-1] if out else "", "- [aa11bb] gcloud auth login — signs you in")

# --- wait --session: picks up an item recorded after it starts, returns once it is ran
write_items("w1", [])
p = subprocess.Popen([str(B / "your-turn"), "wait", "--session", "w1", "--timeout", "20"], stdout=subprocess.PIPE, text=True)
time.sleep(1.5)
check("wait --session: marker written", yt.waiter_alive("w1"), True)
write_items("w1", [item("cc22dd", "make deploy")])
time.sleep(1.5)
subprocess.run([str(B / "your-turn"), "ran", "cc22dd", "0", "--out", "-"], input="deployed ok\n", capture_output=True, text=True)
o, _ = p.communicate(timeout=10)
check("wait --session: exit 0", p.returncode, 0)
check("wait --session: reports the run", "[cc22dd] ran" in o and "deployed ok" in o, True)
check("wait --session: marker removed", yt.waiter_path("w1").exists(), False)
r = subprocess.run([str(B / "your-turn"), "wait", "--session", "w2", "--timeout", "1"], capture_output=True, text=True)
check("wait --session: times out when nothing comes", r.returncode, 2)
if os.environ.get("CLAUDECODE"):  # only inside a Claude Code session is there a parent session to find
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDE_CONFIG_DIR", "YOUR_TURN_CONFIGS")}
    r = subprocess.run([sys.executable, "-I", "-c", f"from importlib.machinery import SourceFileLoader as L; print(L('y','{B}/your-turn').load_module().own_session())"],
                       capture_output=True, text=True, env=env)
    check("own_session: found from the parent claude process", yt.valid_session(r.stdout.strip()), True)

# --- session-start recap
cwd = tmp / "proj"
cwd.mkdir()
now = time.time()
rows = [
    {"session": "s-done", "updated": now - 3600, "goal": "Finished thing", "state": "✓ done", "next": "All merged.", "handoff": "", "cwd": str(cwd)},
    {"session": "s-dead", "updated": now - 1800, "goal": "Died running", "state": "⏳ 2 shells", "next": "", "handoff": "", "cwd": str(cwd)},
    {"session": "s-wait", "updated": now - 600, "goal": "Needs Lashaw", "state": "⏳ 1 shell", "next": "run login", "handoff": "", "cwd": str(cwd)},
    {"session": "s-old", "updated": now - 10 * 86400, "goal": "Ancient", "state": "✓ done", "next": "", "handoff": "", "cwd": str(cwd)},
]
tf = ss.thread_file(tmp, cwd)
tf.parent.mkdir(parents=True, exist_ok=True)
tf.write_text(json.dumps(rows))
write_items("s-wait", [item("zz", "x")])
out = ss.thread_lines(tmp, str(cwd), "me", now=now, live={"s-wait"})
check("recap: header", out[0].startswith("Recent sessions in proj (2 unfinished"), True)
check("recap: waiting first", "Needs Lashaw · 👤 1 waiting on you — next: run login" in out[1], True)
check("recap: closed mid-run", "closed mid-run (⏳ 2 shells)" in out[2], True)
check("recap: finished listed", "Finished thing · ✓ done — last: All merged." in out[3], True)
check("recap: older than 7 days dropped", any("Ancient" in x for x in out), False)
hook = subprocess.run([str(B / "session-state"), "threads"], capture_output=True, text=True,
                      input=json.dumps({"source": "startup", "cwd": str(cwd), "transcript_path": str(proj / "new.jsonl"), "session_id": "new"}))
j = json.loads(hook.stdout or "{}")
check("recap hook: shown to Lashaw and to the model", bool(j.get("systemMessage")) and "Open one only" in j["hookSpecificOutput"]["additionalContext"], True)

print(f"{'FAILED' if fails else 'OK'}: {fails} failure(s)")
sys.exit(1 if fails else 0)
