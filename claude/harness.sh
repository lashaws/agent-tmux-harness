#!/bin/bash
# harness.sh — keep the Claude Code harness (personal ~/.claude and work ~/.claude-work)
# in this repo, and put it back on any Mac.
#
#   bash harness.sh capture   run tests/, then live files in manifest.txt -> home/  (run after changing the harness)
#   bash harness.sh diff      what differs between this machine and the repo; exit 1 if anything
#   bash harness.sh install   home/ -> this machine; backs up every file it replaces
#
# Your home path is stored as __HOME__, so the repo works under any macOS user name.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_HOME="$HERE/home"
MANIFEST="$HERE/manifest.txt"
PLACEHOLDER="__HOME__"

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

capture_to() {
  copy_tree "$HOME" "$1"
  swap "$1" "$HOME" "$PLACEHOLDER"
}

cmd_capture() {
  python3 -I "$HERE/tests/test_harness.py" >/dev/null \
    || { python3 -I "$HERE/tests/test_harness.py" | grep -v '^PASS' >&2; echo "Harness tests failed; nothing captured." >&2; exit 1; }
  local tmp; tmp="$(mktemp -d)"
  capture_to "$tmp"
  rm -rf "$REPO_HOME"; mv "$tmp" "$REPO_HOME"
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
  stage="$(mktemp -d)"; backup="$HOME/.claude-harness-backup/$(date +%Y%m%d-%H%M%S)"
  cp -Rp "$REPO_HOME/." "$stage/"
  swap "$stage" "$PLACEHOLDER" "$HOME"

  # Files: copy each one that differs, backing up the old copy first.
  while IFS= read -r f; do
    rel="${f#"$stage"/}"; live="$HOME/$rel"
    if [ -f "$live" ] && cmp -s "$f" "$live"; then continue; fi
    if [ -e "$live" ] || [ -L "$live" ]; then
      mkdir -p "$(dirname "$backup/$rel")"; cp -p "$live" "$backup/$rel"
    fi
    mkdir -p "$(dirname "$live")"; cp -p "$f" "$live"
    echo "  installed ~/$rel"; changed=$((changed + 1))
  done < <(find "$stage" -type f)
  rm -rf "$stage"

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

  # Shell: source claude.zsh after tmux-last-output.zsh (your-turn-watch needs its stamps).
  if ! grep -q 'zsh/claude.zsh' "$HOME/.zshrc" 2>/dev/null; then
    printf '\n# --- Claude Code: work/personal account switch, twork/twiki, your-turn watcher ---\n[ -f ~/.zsh/claude.zsh ] && source ~/.zsh/claude.zsh\n' >> "$HOME/.zshrc"
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
  *) sed -n '2,9p' "$0"; exit 2 ;;
esac
