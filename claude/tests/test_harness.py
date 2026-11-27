"""Behaviour tests for the Claude Code harness scripts (~/.claude/bin/your-turn, session-state).

Run: python3 -I ~/Dev/agent-tmux-harness/claude/tests/test_harness.py   (harness.sh capture runs it first)
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

# --- defect 1: live permission prompt / input needed
st0 = {"tasks": {}, "questions": []}
check("token: permission prompt leads", ss.token(st0, 0, False, "permission prompt"), "👤 approve prompt")
check("token: permission prompt + running", ss.token(st2, 0, False, "permission prompt"), "👤 approve prompt · ⏳ 1 shell")
check("token: permission prompt + items", ss.token(st0, 1, False, "permission prompt"), "👤 approve prompt · 1 waiting on you")
check("token: input needed is one ask", ss.token(st0, 0, False, "input needed"), "👤 1 waiting on you")
check("token: input needed not doubled with a question", ss.token({"tasks": {}, "questions": ["q"]}, 0, False, "input needed"), "👤 1 waiting on you")
check("token: waiting is not working", ss.token(st0, 0, True, "input needed"), "👤 1 waiting on you")
(tmp / "sessions").mkdir(exist_ok=True)
sess_file = tmp / "sessions" / f"{os.getpid()}.json"
sess_file.write_text(json.dumps({"pid": os.getpid(), "sessionId": "perm-1", "status": "waiting", "waitingFor": "permission prompt"}))
os.environ["SESSION_STATE_PROC_MATCH"] = ""
ptr = proj / "perm-1.jsonl"
ptr.write_text(json.dumps({"type": "user", "message": {"content": "do the thing please"}}) + "\n")
check("live: permission prompt", ss.state_of(str(ptr))[0], "👤 approve prompt")
check("live: stop ignores the prompt", ss.state_of(str(ptr), idle=True)[0], "✓ done")
sess_file.write_text(json.dumps({"pid": os.getpid(), "sessionId": "perm-1", "status": "waiting", "waitingFor": "input needed"}))
check("live: input needed", ss.state_of(str(ptr))[0], "👤 1 waiting on you")
sess_file.unlink()
del os.environ["SESSION_STATE_PROC_MATCH"]

# --- defects 2 and 3: human and browser shells
hl = [{"type": "user", "message": {"content": "sign me in to google please"}},
      a_tool("h1", "~/.claude/bin/agent-browser wait '^https://myaccount\\.google\\.com/' 900"), u_res("h1", "bgh1"),
      a_tool("h2", "while ! ok; do sleep 5; done  # Waits on Lashaw"), u_res("h2", "bgh2"),
      a_tool("h3", "node ~/.claude/skills/walkthrough/cdp-driver.mjs --port 9400"), u_res("h3", "bgh3"),
      a_tool("h4", "npm run build"), u_res("h4", "bgh4")]
htr = proj / "human-1.jsonl"
htr.write_text("".join(json.dumps(x) + "\n" for x in hl))
check("parse: human waits count in 👤, browser server counts nowhere", ss.state_of(str(htr), idle=True)[0], "👤 2 waiting on you · ⏳ 1 shell")
check("open-tasks: human blocks a stop, browser does not", ss.open_tasks(htr), ["bgh1", "bgh2", "bgh4"])

# --- defect 4: nested work in subagent transcripts
def agent_res(tid, aid):
    return {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": tid, "content": "Async agent launched"}]},
            "toolUseResult": {"isAsync": True, "agentId": aid}}


def side(e):
    return {**e, "isSidechain": True}


ntr = proj / "nest-1.jsonl"
ntr.write_text("".join(json.dumps(x) + "\n" for x in [{"type": "user", "message": {"content": "run the whole fleet please"}}, agent_res("n1", "aaa"), agent_res("n2", "ddd")]))
sub = proj / "nest-1" / "subagents"
sub.mkdir(parents=True)
(sub / "agent-aaa.jsonl").write_text("".join(json.dumps(side(x)) + "\n" for x in [
    agent_res("m1", "bbb"), a_tool("m2", "sleep 99"), u_res("m2", "bgm2"),
    a_tool("m3", "~/.claude/bin/agent-browser wait x 900"), u_res("m3", "bgm3")]))
(sub / "agent-bbb.jsonl").write_text("".join(json.dumps(side(x)) + "\n" for x in [agent_res("k1", "ccc")]))
(sub / "agent-ccc.jsonl").write_text("")
(sub / "agent-ddd.jsonl").write_text(json.dumps(side(a_tool("d1", "sleep 5"))) + "\n" + json.dumps(side(u_res("d1", "bgd1"))) + "\n")
check("nested: agents and shells counted recursively", ss.state_of(str(ntr), idle=True)[0], "👤 1 waiting on you · ⏳ 4 agents · 2 shells")
end_note = {"type": "queue-operation", "operation": "enqueue", "content": "<task-notification><task-id>aaa</task-id><status>completed</status></task-notification>"}
with open(ntr, "a") as fh:
    fh.write(json.dumps(end_note) + "\n")
check("nested: a finished agent's subtree is not counted", ss.state_of(str(ntr), idle=True)[0], "⏳ 1 agent · 1 shell")
(sub / "agent-ddd.jsonl").write_text(json.dumps(side(a_tool("d1", "sleep 5"))) + "\n" + json.dumps(side(u_res("d1", "bgd1"))) + "\n" + json.dumps(side(agent_res("d2", "eee"))) + "\n")
check("nested: cache picks up appended lines", ss.state_of(str(ntr), idle=True)[0], "⏳ 2 agents · 1 shell")

# --- subagent-background-tasks.sh: one rule at both exits (SubagentStop and the SubagentHandback tool)
hb_env = {**os.environ, "SESSION_STATE": str(B / "session-state"), "TMPDIR": str(tmp) + "/"}
def guard(payload):
    p = subprocess.run([str(B.parent / "hooks/subagent-background-tasks.sh")], input=json.dumps(payload), capture_output=True, text=True, env=hb_env)
    if not p.stdout.strip():
        return "allow"
    j = json.loads(p.stdout)
    return j.get("reason") or j["hookSpecificOutput"]["permissionDecisionReason"]
hb = {"hook_event_name": "PreToolUse", "tool_name": "SubagentHandback", "session_id": "nest-1", "transcript_path": str(ntr), "agent_id": "ddd"}
check("handback: open task denies, path derived from main transcript", "bgd1" in guard(hb), True)
check("handback: same ids again is allowed", guard(hb), "allow")
check("handback: main thread is allowed", guard({k: v for k, v in hb.items() if k != "agent_id"}), "allow")
check("handback: missing transcript fails open", guard({**hb, "agent_id": "nope"}), "allow")
st_ = {"hook_event_name": "SubagentStop", "agent_id": "ddd", "agent_transcript_path": str(sub / "agent-ddd.jsonl"), "stop_hook_active": False}
check("stop: open task blocks", "bgd1" in guard(st_), True)
check("stop: stop_hook_active passes", guard({**st_, "stop_hook_active": True}), "allow")
check("stop: no open tasks passes", guard({**st_, "agent_transcript_path": str(sub / "agent-ccc.jsonl")}), "allow")

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
