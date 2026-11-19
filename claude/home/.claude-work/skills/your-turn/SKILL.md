---
name: your-turn
description: Reprint the commands still waiting on Lashaw in this session as fresh copyable blocks at the bottom of the conversation, after clearing the ones already done. Use when Lashaw types /your-turn or asks what is waiting on them, what they still need to run, or where a command went.
---

# Your turn: what is still waiting on Lashaw

Open items recorded for this session:

!`~/.claude-work/bin/your-turn list ${CLAUDE_SESSION_ID}`

1. For each item, check read-only whether it already happened (the PR is queued, the
   sign-in works, the resource exists). Clear every finished one:
   `~/.claude-work/bin/your-turn done <id>`. If you cannot check one, keep it open.
2. If you can see the item ran (the watcher records exit code and output when Lashaw runs a command),
   it is already cleared; read it with `~/.claude-work/bin/your-turn wait <id>`. For each item still open,
   start `~/.claude-work/bin/your-turn wait <ids>` with Bash run_in_background so you are woken when it runs.
   Never ask Lashaw to confirm or paste output.
3. Reprint what is left under the heading `**Still waiting on you**`, numbered, in
   handed-over order. For each: one line saying what it does and the output to expect,
   then the command alone in its own fenced bash block (no `cd … &&`, no `!`), so
   `/copy` picks it up whole. Add a `Why yours: <reason>` line to each hand-over.
4. If nothing is left, say so in one line.
