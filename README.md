# dotfiles

LaShaw's terminal setup — tmux dashboard and shell auto-attach.
Clone it on any Mac and run one command to get an identical tmux setup.

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
| `terminal-setup.sh` | Installs tmux + iTerm2, writes `~/.tmux.conf` and `~/tmux-cheatsheet.md`, adds tmux auto-attach to `~/.zshrc` |
| `update.sh` | `git pull` + re-run `terminal-setup.sh` |
| `tmux-cheatsheet.md` | Key bindings reference (also written to `~/tmux-cheatsheet.md` by the setup script) |

## What the setup script touches

- `~/.tmux.conf` — backed up first, but only if the content actually changes
- `~/tmux-cheatsheet.md`
- `~/.zshrc` — appends a tmux auto-attach block, once

It does **not** touch iTerm settings. See below.

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
