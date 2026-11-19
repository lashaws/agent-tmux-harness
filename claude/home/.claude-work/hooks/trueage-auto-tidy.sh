#!/usr/bin/env bash
#
# Lashaw's personal SessionStart hook (not shared with other developers): in a trueage
# checkout, run the repo's own post-merge cleanup instead of only reporting it.
# scripts/git-tidy.sh deletes only branches whose PR merged and worktrees that are clean,
# and never the current branch, main, or the primary worktree.
# To turn it off, delete the SessionStart entry in ~/.claude-work/settings.json.

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
git -C "$dir" remote get-url origin 2>/dev/null | grep -q 'Quantum-Retirement-Solutions/trueage' || exit 0
[ -x "$dir/scripts/git-tidy.sh" ] || exit 0

out="$(cd "$dir" && git fetch -q --prune origin 2>/dev/null; scripts/git-tidy.sh 2>&1)"
n="$(printf '%s\n' "$out" | grep -cE '^(deleted|removed) ')"
[ "$n" -gt 0 ] && echo "auto-tidy: cleaned up $n merged branch(es)/worktree(s) — $(printf '%s\n' "$out" | grep -E '^(deleted|removed) ' | awk '{print $2}' | paste -sd, -)"
exit 0
