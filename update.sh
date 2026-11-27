#!/bin/bash
# update.sh — pull the latest setup from GitHub and apply it to this machine.
# Usage:  bash ~/Dev/agent-tmux-harness/update.sh
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Pulling latest from GitHub"
git -C "$REPO_DIR" pull --ff-only

echo "==> Applying terminal setup"
bash "$REPO_DIR/terminal-setup.sh"

echo "==> Applying the Claude Code harness"
bash "$REPO_DIR/claude/harness.sh" install
