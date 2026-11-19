#!/usr/bin/env bash
# Daily trueage doc-steward run (epic #4345). Started by
# ~/Library/LaunchAgents/com.lashaw.trueage-doc-steward.plist on weekdays at 06:00 local time.
# Runs a headless Claude session in the primary checkout; the session works in its own worktree.
# Log: ~/.claude-work/scheduled/logs/doc-steward-<date>.json
set -uo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# The interactive `claude` shell function sets this for ~/work; launchd doesn't run that function,
# so set it here, or the run uses the default ~/.claude config (no CPP_GATE=off, no DELEGATED_FLOW).
export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
repo="$HOME/work/trueage"
logdir="$HOME/.claude-work/scheduled/logs"
mkdir -p "$logdir"
log="$logdir/doc-steward-$(date +%F).json"

# One run per day, even if launchd fires again after a wake.
[ -s "$log" ] && exit 0

cd "$repo" || exit 1
git pull -q --ff-only >/dev/null 2>&1 || true

prompt='You are the daily doc-steward for trueage. Lashaw approved this run on 2026-10-23 (epic #4345): it may open ONE docs pull request per run without a further go-ahead.
1. Find the merges since the last run: `git fetch origin main`, then `git log origin/main --since="30 hours ago" --format="%h %s"`. Squash subjects end in (#<pr>); `gh pr view <n>` shows the body.
2. Follow `.claude/agents/doc-steward.md`. Check the docs that must track reality (AGENTS.md, docs/WORKING_AGREEMENT.md, docs/README.md, infra/README.md, docs/architecture/, docs/handoff/README.md) against what each merge actually changed in code. Docs are not evidence; read the code.
3. If nothing drifted, change nothing and end with one line: `No drift in <N> merges.`
4. If something drifted:
   - Open an issue titled `Sync docs with <date> merges` (`gh issue create --label "type: documentation" --type Documentation --project TrueAge --assignee @me`).
   - Use EnterWorktree, then `scripts/worktree-setup.sh`, and fix the drift on branch `docs/doc-steward-<YYYY-MM-DD>`.
   - Write `docs/handoff/docs-doc-steward-<YYYY-MM-DD>.md` per docs/handoff/README.md, with an `- **Issue:** #<n>` line and every box ticked.
   - Run `npm run check:agent-docs`.
   - Commit explicit paths, publish with `scripts/ship-pr.sh`, then queue it with the standalone command `gh pr merge <n> --squash --auto`.
5. Docs only, under ~400 lines. Never touch prod, Terraform, workflows, hooks, migrations or other PRs.
End with under 20 lines: the merges checked, the drift found, and the PR number or none.'

claude -p "$prompt" --model sonnet --output-format json < /dev/null > "$log" 2>&1

# A headless EnterWorktree leaves its worktree locked after the session exits, and `npm run tidy`
# won't remove a locked worktree. Unlock this run's worktree so tidy clears it once the PR merges.
for wt in "$repo"/.claude/worktrees/doc-steward-*; do
  [ -d "$wt" ] && git -C "$repo" worktree unlock "$wt" 2>/dev/null
done
exit 0
