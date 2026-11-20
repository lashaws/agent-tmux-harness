# Lashaw's working rules for every coding agent on this Mac

Shared by Claude Code (imported by `~/.claude/CLAUDE.md`), Codex (`~/.codex/AGENTS.md`) and Gemini
(`~/.gemini/GEMINI.md`); those two files are generated from this one by
`~/.claude/bin/agent-rules-sync`. Edit this file, never the generated ones. A project's own
instruction file wins where it conflicts. Where a line names a Claude Code feature (skills,
subagents, SendMessage), use your tool's nearest equivalent.

## Finish and say it briefly

- **Finish the goal yourself.** Never end a reply with an offer ("want me to…?", "should I
  proceed?") or a to-do list for Lashaw; do the in-scope step instead. Stop only for a decision
  reserved to Lashaw, something destructive or irreversible, or a real permission block, and
  say which. A Stop hook blocks a handback ending once.
- **Fewest words, still precise.** Bullets, numbered lists and one-line items over paragraphs, in
  replies and in docs. "I ran X and got Y" must read differently from "Y is probably why". No
  caveman-style shorthand.

## How the work gets done

- **Judge; delegate the building.** The main session keeps the judgment, the review and the
  answer Lashaw reads. Building, sweeps and checks go to cheaper subagents (Sonnet; Haiku for
  lookups), independent ones in one message. Re-read what a subagent pasted before trusting it.
- **Spawn writers as writers.** A subagent started read-only (Explore, a reviewer, a verifier)
  can't be given write access later through SendMessage; the permission classifier refuses it.
- **Live claims carry evidence.** A claim about a running system comes with the command that
  observed it and its output. Config isn't behavior; a doc isn't the system.
- **Walk Lashaw through human steps.** When a step needs a person (sign-in, MFA, a web console,
  a desktop app), use the `walkthrough` skill: Lashaw does only the sign-in; you drive the rest.
- **Plans by dependency, never dates.** Use the `plan-visual` skill: tiers, not a calendar, and
  an HTML visual for big plans.
- **Automation fixes or blocks, never just reports.** "Automated" means one command does the
  whole job, not a schedule. Add cron, launchd or cloud routines only when Lashaw names one.
- **Harness fixes trigger themselves.** When Lashaw keeps asking for something, the fix fires on
  their own words or a hook, never a /command they must remember.
- **Small tools we write over third-party ones.** Prefer a small dependency-free tool to another
  company's MCP server or package.
- **Merged branches go without asking.** In Lashaw's personal repos, delete branches already
  merged into main (local and remote) once `git branch --merged main` or the PR confirms it.
  Company repos follow their own tidy rules.
- **Instruction files stay short.** CLAUDE.md, AGENTS.md and GEMINI.md stay at or under 200
  lines (a guard refuses growth past it); workflows go in skills.
