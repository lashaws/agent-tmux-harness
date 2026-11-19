# Lashaw's personal notes for Claude (all personal projects)

A project's own CLAUDE.md wins wherever it conflicts with this file. In life-wiki that means its
curator gates, egress rules and clinical-scope rules.

## Default for every task: finish it yourself

- **Finish the whole goal in this session.** A list of findings is where the work starts: fix
  what you find instead of reporting it. Send independent work to subagents in one message.
- **Approval stands.** Once Lashaw approves a plan or a step, don't ask again about anything
  inside it. Don't end a turn with "want me to…?" or with a list of steps for them to do.
- **When a step has to be Lashaw's** (a permission denial, a sign-in, MFA, a QR code, a
  curator-only command), put the exact command in this message: each in its own fenced
  ```bash block, no `cd … &&`, each with what it does and the output to expect. Never write
  "see above". Keep working on everything else.
- **Commands and paths must survive line wrapping.** Claude Code wraps long lines with real
  newlines, so a wrapped command pastes broken and a wrapped path won't cmd+click (2026-10-22).
  - One command per fenced ```bash block, nothing else in it. Lashaw copies it whole with
    `/copy` and picks the block; that copy has no line breaks.
  - A file Lashaw might open is a markdown link to an absolute file URL, e.g.
    `[notes.md](file://__HOME__/path/to/notes.md)` (`%20` for spaces). Only links
    become terminal hyperlinks; inline code and bare paths don't. This replaces the default
    `file_path:line_number` style; put the line in the link text (`[app.ts:42](file:///…/app.ts)`).
  - When pointing Lashaw at a file to open (an artifact, an output, a report), link its folder
    right after it too, e.g. `([folder](file://__HOME__/path/to/))`: a file:// link to a
    directory opens in Finder. An artifact also gets its claude.ai link.
- **Hand-overs run themselves.** Before writing a hand-over, start `~/.claude/bin/your-turn wait
  --session` in the background; then put the command under `**Your turn** — <what it unblocks>`
  with a `Why yours:` line. Their shell reports the run and its output, so never ask whether it ran (the Why yours
  line is Stop-hook enforced). A handed-over command never prints a secret; the watcher's skip
  list and redaction are only a backstop.
- **Open commands ride at the bottom.** While any hand-over is still open, end every reply with
  `**Still waiting on you**`: each open command again (one line on what it does and the output to
  expect, then the command alone in its block), so `/copy` always has it; never point back to an
  earlier reply. Stop-hook enforced.
- **Done is visible.** The status line shows `👤 waiting on you` (leads whenever Lashaw has
  something to do, with any running work after it), `⏳ running`, `⚙ working` or `✓ done`, and
  `💤` while /sleep is scheduled. A `your-turn wait` watcher is not counted as running. A check
  due after this session (next run, tomorrow, next week) never stays in a session-bound loop or
  monitor, which dies on close: move it to an issue checkbox or a scheduled job, say where, and
  end the in-session watcher.
- **Sleep mode** is Lashaw's `/sleep` (a time, or none for "when every session is done"). A hook then injects
  the away rules and the T-20 wrap-up warning into every live session; follow them. Never start it yourself.
- **Recent sessions** in the project are recapped at session start, to Lashaw and to you, one line
  each (unfinished first, then the last finished ones). Open one only when Lashaw's prompt
  continues it; otherwise ignore the list. End a reply that leaves work open with a `Next:` line.
- **Stop only for** a decision the project reserves for Lashaw (in life-wiki: egress, scope,
  spend tier, git-history rewrite, `curator-gate` items), something destructive or
  irreversible, or a real permission block. Say which one it is.
- **End when it's done.** No "next steps", "you might also" or "one more thing" by default. If
  an idea is worth doing and in scope, do it instead of suggesting it. Raise something only if
  it needs Lashaw's decision or is a risk they'd want to know about. In a clinical record, a
  contradiction or a safety concern always counts as a risk. Otherwise say nothing.
- **Keep prose precise, not compressed.** "I ran X and got Y" must read differently from "Y is
  probably why". No caveman-style shorthand.
