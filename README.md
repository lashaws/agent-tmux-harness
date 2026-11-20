# agent-tmux-harness

LaShaw's setup for running coding agents side by side in tmux — tmux dashboard, shell auto-attach, and the Claude Code
harness for both accounts (personal `~/.claude`, work `~/.claude-work`).
Clone it on any Mac and run two commands to get the same setup.

## New machine

Requires [Homebrew](https://brew.sh) and the GitHub CLI (`brew install gh`, then `gh auth login`).

```bash
mkdir -p ~/Dev
gh repo clone lashaws/agent-tmux-harness ~/Dev/agent-tmux-harness
ln -s ~/Dev/agent-tmux-harness ~/dotfiles     # the harness's own scripts and notes use ~/dotfiles
bash ~/dotfiles/terminal-setup.sh
bash ~/dotfiles/claude/harness.sh install
```

Then sign in to each Claude account once: `claude` in your home folder (personal) and
`claude` under `~/work` (work, which the `claude()` wrapper points at `~/.claude-work`).

Quit iTerm once with `Cmd-Q` and reopen it afterwards.

## Existing machine — pull latest and re-apply

```bash
bash ~/dotfiles/update.sh
```

That pulls from GitHub and re-runs the setup. It is safe to run repeatedly:
existing configs are backed up with a timestamp, and the `.zshrc` block is only
added once.

## Making changes

Edit the files here, then push so every other machine can pick them up. For the Claude
harness, edit the live files as usual and run `bash claude/harness.sh capture` first.

```bash
cd ~/dotfiles
git add -A && git commit -m "describe the change" && git push
```

## What's in here

| File | What it does |
|---|---|
| `terminal-setup.sh` | Installs tmux + iTerm2 app, installs `tmux.conf`, writes `~/tmux-cheatsheet.md`, adds tmux auto-attach to `~/.zshrc` |
| `update.sh` | `git pull`, re-run `terminal-setup.sh`, then `claude/harness.sh install` |
| `tmux.conf` | The actual `~/.tmux.conf` — copied in as-is by the setup script |
| `claude/` | The Claude Code harness for both accounts — see below |
| `tmux-last-output` | Backs the `prefix y/Y/S/C-s` copy bindings in `tmux.conf` — grabs the last command's output (or whole scrollback) from a pane, any length → installed to `~/.local/bin/tmux-last-output` |
| `tmux-last-output.zsh` | zsh `preexec`/`precmd` hooks that stamp each pane with where the last command's output starts/ends, so the script above knows what to grab → installed to `~/.zsh/tmux-last-output.zsh`, sourced from `~/.zshrc` |
| `tmux-cheatsheet.md` | Key bindings reference (also written to `~/tmux-cheatsheet.md` by the setup script) |

## What the setup script touches

- `~/.tmux.conf` — backed up first, but only if the content actually changes
- `~/.local/bin/tmux-last-output` and `~/.zsh/tmux-last-output.zsh` — installed, and a source line appended to `~/.zshrc` once
- `~/tmux-cheatsheet.md`
- `~/.zshrc` — appends a tmux auto-attach block and a tmux-last-output source line, each once

It does **not** touch iTerm settings. See below.

## Claude Code harness (`claude/`)

`claude/manifest.txt` lists every hand-made piece of both accounts: `CLAUDE.md`,
`settings.json` (hooks, permissions, plugins, status line), `hooks/`, `bin/`
(your-turn, session-state, sleep-mode), agents, personal skills, themes, the status
lines, `~/.zsh/claude.zsh` (account switch, `twork`/`twiki`), `~/.zsh/your-turn-watch.zsh`
and the doc-steward launch agent. `claude/home/` holds them at their `$HOME`-relative paths,
with your home folder written as `__HOME__` so a different macOS user name still works.

| Command | What it does |
|---|---|
| `bash claude/harness.sh capture` | Copies the live files into `claude/home/`, then scans them with gitleaks. Run it after changing the harness, then commit. |
| `bash claude/harness.sh diff` | Shows what differs between this machine and the repo (exit 1 if anything does). |
| `bash claude/harness.sh install` | Copies `claude/home/` onto this machine, backing up each replaced file to `~/.claude-harness-backup/<time>/`; relinks the work account's shared `your-turn`, `rate` and `sleep`; adds the `claude.zsh` source line to `~/.zshrc`; loads the doc-steward agent if `~/work/trueage` exists; installs each account's enabled plugins. Safe to re-run. |

This repo is public, so capture also keeps private context out of it:

- The auto-mode classifier block is stripped from every `settings.json` (it describes employer accounts and personal projects). `install` keeps the machine's own block when it replaces a `settings.json`; `diff` compares without it.
- `~/.claude/local/public-scrub.tsv` (local, mode 600, never captured) maps `real<TAB>placeholder` per line (`#` comments allowed). Capture swaps real to placeholder in text files, longest first; `install` swaps back when the file exists, else the placeholders stay.
- After capture, a leak gate scans the whole repo for every real value (case-insensitive) and for a leftover auto-mode block. On a hit it prints `file:line`, exits non-zero and you must not commit. Capture also refuses to run without the map.
- A fresh Mac needs its own auto-mode block (set in Claude Code) and its own `public-scrub.tsv`.

Deliberately **not** tracked: sign-ins and account state (`.claude.json`, Keychain),
history, transcripts and memory (`projects/`), plugin caches, and skills synced from
claude.ai or installed by other tools (`skills/synced`, `google-agents-cli-*`).
Needs `jq`, `python3`, `tmux` and `gh` (the install names any that are missing).

## iTerm setup (one-time, manual)

This is deliberately not scripted. iTerm keeps its preferences in memory and
rewrites the plist when it quits, so `defaults write` from a script silently
reverts — and the Dynamic Profile approach that does work tags the profile
`Dynamic` in the profile list, which is why it looked different from other
machines.

Set it up once in the UI instead:

1. **Settings → Profiles**, pick the profile you want (or `+` for a new one) and
   name it `tmux`.
2. **Colors** tab — choose your scheme, and tick *Use separate colors for light
   and dark mode* if you want it to follow macOS appearance.
3. **Text** tab — font `Monaco 12`.
4. **Keys → Key Mappings → Presets… → Natural Text Editing.** This one preset
   supplies all of it: Option+←/→ jump a word, Cmd+←/→ go to line start/end,
   Option+Delete deletes a word, Cmd+Delete clears to the line start.
5. **Other Actions… → Set as Default**.

Quit iTerm with `Cmd-Q` once afterwards so the change is written to disk.
