# dotfiles

LaShaw's terminal setup — tmux dashboard, iTerm2 profile, and shell auto-attach.
Clone it on any Mac and run one command to get an identical terminal.

## New machine

Requires [Homebrew](https://brew.sh) and the GitHub CLI (`brew install gh`, then `gh auth login`).

```bash
mkdir -p ~/Work/dev
gh repo clone lashaws/dotfiles ~/Work/dev/dotfiles
ln -s ~/Work/dev/dotfiles ~/dotfiles          # convenience symlink, optional
bash ~/Work/dev/dotfiles/terminal-setup.sh
```

Quit iTerm once with `Cmd-Q` and reopen it afterwards.

## Existing machine — pull latest and re-apply

```bash
bash ~/Work/dev/dotfiles/update.sh
```

That pulls from GitHub and re-runs the setup. It is safe to run repeatedly:
existing configs are backed up with a timestamp, and the `.zshrc` block is only
added once.

## Making changes

Edit the files here, then push so every other machine can pick them up:

```bash
cd ~/Work/dev/dotfiles
git add -A && git commit -m "describe the change" && git push
```

## What's in here

| File | What it does |
|---|---|
| `terminal-setup.sh` | Installs tmux + iTerm2, writes the `LaShaw Homebase` iTerm profile, writes `~/.tmux.conf`, adds tmux auto-attach to `~/.zshrc` |
| `update.sh` | `git pull` + re-run `terminal-setup.sh` |
| `tmux-cheatsheet.md` | Key bindings reference (also written to `~/tmux-cheatsheet.md` by the setup script) |

## What the setup script touches

- `~/Library/Application Support/iTerm2/DynamicProfiles/lashaw-homebase.json` — the iTerm profile, set as default
- `~/.tmux.conf` — backed up first if one exists
- `~/tmux-cheatsheet.md`
- `~/.zshrc` — appends a tmux auto-attach block, once
