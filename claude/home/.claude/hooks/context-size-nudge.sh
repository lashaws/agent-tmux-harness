#!/usr/bin/env bash
#
# Stop hook (personal config) — tell Lashaw when this session's context has grown large.
# Ported from trueage's .claude/hooks/context-size-nudge.sh (#3606), minus its handoff soft-stop.
#
# Why: every turn re-reads the whole context, so a turn costs more as the session grows. Only
# Lashaw can start a fresh session or /compact, so the message goes to them (systemMessage),
# never to the model, and it never blocks. Says it once at 300k tokens, then every 200k after.
#
# Skips a project that ships its own context-size-nudge.sh (life-wiki does), so it never
# fires twice. Fails quiet: no transcript, no usage line or no python means no message.

set -uo pipefail

[ -x "${CLAUDE_PROJECT_DIR:-/nonexistent}/.claude/hooks/context-size-nudge.sh" ] && exit 0

payload="$(cat)"

parsed="$(printf '%s' "$payload" | python3 -c '
import json, os, re, sys
try:
    data = json.load(sys.stdin)
except (ValueError, TypeError):
    sys.exit(0)
path = data.get("transcript_path") or ""
sid = re.sub(r"[^A-Za-z0-9_-]", "", str(data.get("session_id") or ""))
if not sid or not os.path.isfile(path):
    sys.exit(0)
with open(path, "rb") as f:
    f.seek(0, os.SEEK_END)
    f.seek(max(0, f.tell() - 4_000_000))
    lines = f.read().decode("utf-8", "ignore").splitlines()
for line in reversed(lines):
    if "\"usage\"" not in line:
        continue
    try:
        entry = json.loads(line)
    except ValueError:
        continue
    usage = (entry.get("message") or {}).get("usage") if entry.get("type") == "assistant" else None
    if usage:
        tokens = sum(usage.get(k) or 0 for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
        print("%s %d" % (sid, tokens))
        break
' 2>/dev/null)"

[ -n "$parsed" ] || exit 0
sid="${parsed%% *}"
tokens="${parsed##* }"

threshold=300000
step=200000
[ "$tokens" -ge "$threshold" ] 2>/dev/null || exit 0
band=$(( (tokens - threshold) / step + 1 ))

statedir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/pending"
mkdir -p "$statedir" 2>/dev/null || exit 0
state="$statedir/${sid}.context-band"
last="$(cat "$state" 2>/dev/null || echo 0)"
[ "$band" -gt "${last:-0}" ] 2>/dev/null || exit 0
printf '%s\n' "$band" > "$state"

python3 -c '
import json, sys
k = int(sys.argv[1]) // 1000
print(json.dumps({"systemMessage": "Context is at %dk tokens, and every turn re-reads all of it. When this task is done, start a fresh session (or /compact) for the next one." % k}))
' "$tokens"
exit 0
