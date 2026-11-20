#!/usr/bin/env bash
#
# Lashaw's personal SessionStart hook (not shared with other developers): in a trueage
# checkout, run the repo's own post-merge cleanup instead of only reporting it.
# scripts/git-tidy.sh deletes only branches whose PR merged and worktrees that are clean,
# and never the current branch, main, or the primary worktree.
# To turn it off, delete the SessionStart entry in ~/.claude-work/settings.json.
#
# The tidy takes 15-40 s (worktree removal, per-branch gh lookups) and Claude Code holds the
# first prompt until every SessionStart hook exits, so the tidy runs detached in the
# background and this hook returns at once. It reports what the previous run cleaned up,
# once. A lock keeps two sessions starting together from tidying at the same time.

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
git -C "$dir" remote get-url origin 2>/dev/null | grep -q -E 'Quantum-Retirement-Solutions/(quantum|trueage)(\.git)?$' || exit 0
[ -x "$dir/scripts/git-tidy.sh" ] || exit 0

state="$HOME/.claude-work/state/trueage-auto-tidy"
mkdir -p "$state"
lock="$state/lock"
last="$state/last-result"

# Report the previous run's cleanup, then clear it so it is said only once.
if [ -s "$last" ]; then
  cat "$last"
  : >"$last"
fi

# A lock older than 10 minutes belongs to a run that died; take it over.
if [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
  rmdir "$lock" 2>/dev/null
fi
mkdir "$lock" 2>/dev/null || exit 0

nohup bash -c '
  dir="$1"; lock="$2"; last="$3"
  trap "rmdir \"$lock\" 2>/dev/null" EXIT
  out="$(cd "$dir" && git fetch -q --prune origin 2>/dev/null; scripts/git-tidy.sh 2>&1)"
  n="$(printf "%s\n" "$out" | grep -cE "^(deleted|removed) ")"
  [ "$n" -gt 0 ] && echo "auto-tidy (last session start): cleaned up $n merged branch(es)/worktree(s) — $(printf "%s\n" "$out" | grep -E "^(deleted|removed) " | awk "{print (\$1==\"removed\" ? \$NF : \$2)}" | paste -sd, -)" >>"$last"
' _ "$dir" "$lock" "$last" </dev/null >/dev/null 2>&1 &
disown 2>/dev/null
exit 0
