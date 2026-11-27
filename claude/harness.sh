#!/bin/bash
# harness.sh — keep the Claude Code harness (personal ~/.claude and work ~/.claude-work)
# in this repo, and put it back on any Mac.
#
#   bash harness.sh capture   run tests/, then live files in manifest.txt -> home/  (run after changing the harness)
#   bash harness.sh diff      what differs between this machine and the repo; exit 1 if anything
#   bash harness.sh install   home/ -> this machine; backs up every file it replaces
#
# Your home path is stored as __HOME__, so the repo works under any macOS user name.
# This repo is PUBLIC, so capture also keeps private context out of it:
#   - the auto-mode classifier key is dropped from every settings.json (install keeps the machine's own);
#   - every `real<TAB>placeholder` line in ~/.claude/local/public-scrub.tsv (local, never captured)
#     is swapped real -> placeholder in text files; install swaps them back when the map exists;
#   - a leak gate scans the whole repo for the map's real values and fails capture if any remain.
# A fresh Mac needs its own auto-mode block and its own public-scrub.tsv. HARNESS_TARGET=<dir> makes
# install copy only the files, into <dir> (for testing).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_HOME="$HERE/home"
MANIFEST="$HERE/manifest.txt"
PLACEHOLDER="__HOME__"
REPO_ROOT="$(cd "$HERE/.." && pwd -P)"
# The settings key holding private classifier prose (spelled in two parts so a repo grep for the key finds no hit here).
AMK="auto""Mode"
SCRUB_MAP="${HARNESS_SCRUB_MAP:-$HOME/.claude/local/public-scrub.tsv}"

entries() { grep -vE '^[[:space:]]*(#|$)' "$MANIFEST" | grep -v '^link ' || true; }
links()   { grep '^link ' "$MANIFEST" | cut -d' ' -f2- || true; }

# copy_tree <from-root> <to-root> — every manifest entry, mirrored (stale files in <to> removed)
copy_tree() {
  local from="$1" to="$2" e
  while IFS= read -r e; do
    if [ -d "$from/$e" ]; then
      mkdir -p "$to/$e"
      rsync -a --delete --exclude .DS_Store --exclude __pycache__ --exclude '*.pyc' \
        --exclude '*.bak*' "$from/$e/" "$to/$e/"
    elif [ -f "$from/$e" ]; then
      mkdir -p "$(dirname "$to/$e")"
      cp -p "$from/$e" "$to/$e"
    else
      echo "  not on this machine, skipped: ~/$e" >&2
    fi
  done < <(entries)
}

# swap <dir> <from> <to> — replace a literal string in every text file under <dir>
swap() {
  grep -rlF "$2" "$1" 2>/dev/null | while IFS= read -r f; do
    LC_ALL=C sed -i '' "s|$2|$3|g" "$f"
  done
}

# scrub <dir> fwd|rev — literal real<->placeholder swap from the scrub map, longest first, text files only
scrub() {
  [ -f "$SCRUB_MAP" ] || return 0
  python3 -I -c '
import os, sys
mp, root, mode = sys.argv[1:4]
pairs = []
for line in open(mp, encoding="utf-8"):
    line = line.rstrip("\n")
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    real, ph = line.split("\t")
    pairs.append((real, ph) if mode == "fwd" else (ph, real))
pairs.sort(key=lambda p: -len(p[0]))
for d, _, files in os.walk(root):
    for n in files:
        f = os.path.join(d, n)
        if os.path.islink(f):
            continue
        b = open(f, "rb").read()
        if b"\0" in b:
            continue
        o = b
        for a, c in pairs:
            o = o.replace(a.encode(), c.encode())
        if o != b:
            open(f, "wb").write(o)
' "$SCRUB_MAP" "$1" "$2"
}

# strip_am <settings.json> — the file without its auto-mode key, otherwise untouched
strip_am() {
  if jq -e --arg k "$AMK" 'has($k)' "$1" >/dev/null 2>&1; then jq --indent 2 --arg k "$AMK" 'del(.[$k])' "$1"; else cat "$1"; fi
}

capture_to() {
  copy_tree "$HOME" "$1"
  swap "$1" "$HOME" "$PLACEHOLDER"
  scrub "$1" fwd
  local f
  while IFS= read -r f; do
    if jq -e --arg k "$AMK" 'has($k)' "$f" >/dev/null 2>&1; then
      strip_am "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
  done < <(find "$1" -type f -name settings.json)
}

# leak_gate — fail if any real value from the scrub map, or any auto-mode key, is left in the repo
leak_gate() {
  local hits=0 pats=() real f
  while IFS= read -r real; do pats+=(-e "$real"); done < <(grep -vE '^[[:space:]]*(#|$)' "$SCRUB_MAP" | cut -f1)
  if [ "${#pats[@]}" -gt 0 ]; then
    # file:line only, so the log never prints the secret itself
    if grep -rnIiF "${pats[@]}" "$REPO_ROOT" --exclude-dir=.git | cut -d: -f1,2 | sed 's/^/  leak: /' | grep .; then hits=1; fi
  fi
  while IFS= read -r f; do
    if jq -e --arg k "$AMK" 'has($k)' "$f" >/dev/null 2>&1; then echo "  leak: auto-mode key in $f"; hits=1; fi
  done < <(find "$REPO_HOME" -type f -name settings.json)
  if [ "$hits" = 1 ]; then
    echo "LEAK GATE FAILED: private strings remain in the repo (listed above). Do NOT commit; fix the source or the map, then re-run capture." >&2
    return 1
  fi
}

cmd_capture() {
  [ -f "$SCRUB_MAP" ] || { echo "No scrub map at $SCRUB_MAP: capture would publish private strings. Create it (real<TAB>placeholder per line)." >&2; exit 1; }
  python3 -I "$HERE/tests/test_harness.py" >/dev/null \
    || { python3 -I "$HERE/tests/test_harness.py" | grep -v '^PASS' >&2; echo "Harness tests failed; nothing captured." >&2; exit 1; }
  local tmp; tmp="$(mktemp -d)"
  capture_to "$tmp"
  rm -rf "$REPO_HOME"; mv "$tmp" "$REPO_HOME"
  leak_gate || exit 1
  if command -v gitleaks >/dev/null 2>&1; then
    gitleaks dir "$REPO_HOME" --no-banner --redact >/dev/null 2>&1 \
      || { echo "gitleaks found a possible secret under home/ — check before committing." >&2; exit 1; }
  fi
  echo "Captured into $REPO_HOME. Review with: git -C \"$HERE\" status"
}

cmd_diff() {
  local tmp; tmp="$(mktemp -d)"
  capture_to "$tmp"
  if diff -ru "$REPO_HOME" "$tmp"; then echo "No drift: this machine matches the repo."; rc=0
  else rc=1; fi
  rm -rf "$tmp"; return $rc
}

cmd_install() {
  local stage backup changed=0 f rel live target path
  stage="$(mktemp -d)"; backup="${HARNESS_TARGET:-$HOME}/.claude-harness-backup/$(date +%Y%m%d-%H%M%S)"
  cp -Rp "$REPO_HOME/." "$stage/"
  swap "$stage" "$PLACEHOLDER" "$HOME"
  scrub "$stage" rev

  # HARNESS_TARGET (testing): copy the files into that folder instead of $HOME, and stop.
  local root="${HARNESS_TARGET:-$HOME}"

  # Files: copy each one that differs, backing up the old copy first.
  while IFS= read -r f; do
    rel="${f#"$stage"/}"; live="$root/$rel"
    if [ -f "$live" ]; then
      # settings.json: the repo has no auto-mode block; compare without the live one, then keep it on replace.
      if [ "$(basename "$rel")" = settings.json ]; then
        strip_am "$live" | cmp -s - "$f" && continue
        if jq -e --arg k "$AMK" 'has($k)' "$live" >/dev/null 2>&1; then
          jq --indent 2 --slurpfile live "$live" --arg k "$AMK" '. + {($k): $live[0][$k]}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
        fi
      elif cmp -s "$f" "$live"; then continue; fi
    fi
    if [ -e "$live" ] || [ -L "$live" ]; then
      mkdir -p "$(dirname "$backup/$rel")"; cp -p "$live" "$backup/$rel"
    fi
    mkdir -p "$(dirname "$live")"; cp -p "$f" "$live"
    echo "  installed ~/$rel"; changed=$((changed + 1))
  done < <(find "$stage" -type f)
  rm -rf "$stage"
  if [ -n "${HARNESS_TARGET:-}" ]; then echo "Done: $changed change(s) into $root (HARNESS_TARGET; nothing else touched)."; return 0; fi

  # Symlinks shared between the two accounts.
  while read -r path target; do
    live="$HOME/$path"
    if [ -L "$live" ] && [ "$(cd "$(dirname "$live")" && realpath "$target")" = "$(realpath "$live")" ]; then
      continue
    fi
    if [ -e "$live" ] || [ -L "$live" ]; then
      mkdir -p "$(dirname "$backup/$path")"; mv "$live" "$backup/$path"
    fi
    mkdir -p "$(dirname "$live")"; ln -s "$target" "$live"
    echo "  linked ~/$path -> $target"; changed=$((changed + 1))
  done < <(links)

  # Machine-only layer (never captured): CLAUDE.md imports local/rules.md, so make sure it exists.
  if [ ! -f "$HOME/.claude/local/rules.md" ]; then
    mkdir -p "$HOME/.claude/local/hooks/pre-tool-use"
    printf '# This Mac only (not in dotfiles)\n\nAdd rules for this machine alone here.\n' > "$HOME/.claude/local/rules.md"
    echo "  created an empty ~/.claude/local/rules.md"
  fi

  # Codex and Gemini read generated copies of ~/.claude/agent-rules.md (+ local rules).
  "$HOME/.claude/bin/agent-rules-sync" && echo "  synced ~/.codex/AGENTS.md and ~/.gemini/GEMINI.md"
  [ -f "$HOME/.codex/hooks.json" ] && echo "  Codex: open codex once and approve the new hooks when it asks (hooks need review)"

  # Shell: source claude.zsh after tmux-last-output.zsh (your-turn-watch needs its stamps).
  if ! grep -q 'zsh/claude.zsh' "$HOME/.zshrc" 2>/dev/null; then
    printf '\n# --- Claude Code: work/personal account switch, twork, your-turn watcher ---\n[ -f ~/.zsh/claude.zsh ] && source ~/.zsh/claude.zsh\n' >> "$HOME/.zshrc"
    echo "  added the claude.zsh source line to ~/.zshrc"
  fi

  # Weekday doc-steward run for trueage, only where trueage is checked out.
  local plist="$HOME/Library/LaunchAgents/com.lashaw.trueage-doc-steward.plist"
  if [ -f "$plist" ] && [ -d "$HOME/work/trueage" ]; then
    mkdir -p "$HOME/.claude-work/scheduled/logs"
    if ! launchctl print "gui/$(id -u)/com.lashaw.trueage-doc-steward" >/dev/null 2>&1; then
      launchctl bootstrap "gui/$(id -u)" "$plist" && echo "  doc-steward launch agent loaded"
    fi
  fi

  # Plugins each account has enabled (built-ins need no install).
  if command -v claude >/dev/null 2>&1; then
    install_plugins "$HOME/.claude" "$HOME/.claude/settings.json"
    install_plugins "$HOME/.claude-work" "$HOME/.claude-work/settings.json"
  else
    echo "  claude CLI not found: install Claude Code, then re-run this to add plugins."
  fi

  for tool in jq python3 tmux gh; do
    command -v "$tool" >/dev/null 2>&1 || echo "  missing dependency: $tool (brew install $tool)"
  done
  echo "Done: $changed change(s)."
  [ -d "$backup" ] && echo "Replaced files were backed up to $backup"
  return 0
}

install_plugins() {
  local dir="$1" settings="$2" p
  [ -f "$settings" ] || return 0
  python3 -c 'import json,sys
for k,v in json.load(open(sys.argv[1])).get("enabledPlugins",{}).items():
    if v and not k.endswith("@builtin"): print(k)' "$settings" | while IFS= read -r p; do
    [ -d "$dir/plugins/cache/${p#*@}/${p%@*}" ] && continue
    CLAUDE_CONFIG_DIR="$dir" claude plugin install "$p" --scope user </dev/null >/dev/null 2>&1 \
      && echo "  plugin $p installed for $dir" \
      || echo "  plugin $p: install it from Claude Code (/plugin) for $dir"
  done
}

case "${1:-}" in
  capture) cmd_capture ;;
  diff)    cmd_diff ;;
  install) cmd_install ;;
  *) sed -n '2,15p' "$0"; exit 2 ;;
esac
