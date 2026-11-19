# Lashaw's local notes for Claude (not in any repo)

**Main session only.** A subagent follows its definition and its brief, not this file.

The general defaults (finish the goal, approval stands, plain commands that survive wrapping, when
to stop, end when done) live in `~/.claude/CLAUDE.md`, imported here because this config dir never
loads that file on its own. These are the trueage additions.

@~/.claude/CLAUDE.md

## Walk Lashaw through roadblocks

Lashaw has written "complete this autonomously, spin up a browser to walk me through roadblocks,
otherwise finish on your own" in dozens of prompts. Assume it on every task.

- If a step needs a human (sign-in, MFA, a secret, a console or desktop app), open the headed CDP
  Chrome (memory: live-test-walkthrough-recipe). Lashaw does only the sign-in; you drive the rest
  and check it. For a desktop or SaaS tool, get the one sign-in, then drive it through its CLI or API.
- Also stop for a design in Fred's zone that he hasn't approved.
- Live checks and smoke tests go to a background `verifier`, so the browser work stays out of the
  main session's context.
- **Tag every command you hand Lashaw.** Open the hand-over with the line
  `**Your turn** — <what it unblocks>`, then per step: one line saying what it does and the
  output to expect, then the command alone in its fenced block. A Stop hook records each block
  under that heading (`~/.claude-work/bin/your-turn`); the status line counts open items,
  `/your-turn` reprints them, the notification names the first. Untagged commands are lost
  in the scrollback once background agents report.
- Each hand-over carries `Why yours: <what refused you>` (a named hook, the classifier, a sign-in,
  MFA, a desktop app, a decision reserved to Lashaw). Try the step yourself first; the Stop hook
  blocks a hand-over without the line.
- Right after a hand-over, start `~/.claude-work/bin/your-turn wait <ids>` with
  `run_in_background`. `~/.zsh/your-turn-watch.zsh` sees Lashaw run the command in tmux, saves its
  output and marks it done, so you wake with the exit code and output. Never ask "did it run?" or
  for pasted output. A handed-over command never prints a secret: pipe it to a file or variable,
  or print only a length or fingerprint (the watcher also skips and redacts, as a backstop).
- `/sleep` is Lashaw's alone (a time, or none for "when every session is done"); follow the away
  rules and the T-20 wrap-up warning its hook injects, and never start it yourself.
- SessionStart lists open threads (one line each). Open one only when Lashaw's prompt continues
  it; otherwise ignore the list. End a reply that leaves work open with a `Next:` line, which
  becomes that thread's next step.
- The status line shows the session's state (`⏳ running`, `⚙ working`, `👤 waiting on you`,
  `✓ done`, `💤` while /sleep is set), so
  Lashaw never asks "can I close?". A check due after this session (next run, tomorrow, next
  week) never lives in a session-bound loop or monitor, which dies on close: put it in an issue
  checkbox or a scheduled job outside the session, say where, and end the in-session watcher.
- When an item is done (you checked the live result, or Lashaw says so), clear it with
  `~/.claude-work/bin/your-turn done <id>`. Each prompt Lashaw sends lists the open ids.
- History: memories walk-through-everything, fix-obvious-followups-dont-ask,
  finish-the-goal-no-followups, cleanup-proactively.

## trueage — merging PRs

The rules (queue every non-draft PR in the build phase, rebasing, the delegated flow, prod
break-glass) are in `docs/WORKING_AGREEMENT.md` ("The delegated flow", "Prod break-glass"). Only
the mechanics of this machine are here.

- Run `gh pr merge <n> --squash --auto` **as its own plain command**. Never chain it (no `cd … &&`
  before it, no `&& gh pr view` after it). The allow rule `Bash(gh pr merge *)` only covers a
  standalone merge; a chained one goes to the auto-mode classifier, which refuses it as
  "Merge Without Review". `--admin` is refused while the merge queue is on.
- The allow rule lives in the primary checkout's gitignored `.claude/settings.local.json`. A session
  that starts in the primary checkout and moves with `EnterWorktree` keeps it (checked live
  2026-10-23). `scripts/worktree-setup.sh` copies the file into a worktree for a session started
  there. If a standalone merge is still refused, give Lashaw the exact command.
- `DELEGATED_FLOW=on` is set in `~/.claude-work/settings.json`. `ship-pr.sh` prints the merge line
  for each unqueued PR and lists the CONFLICTING ones: queue them, and run each conflict through
  `scripts/rebase-pr.sh <n>` in a background implementer. That replaces the end-of-session sweep.
- After a merge, `scripts/in-prod.sh <sha>` says whether prod has it. A red Release is yours to fix.
