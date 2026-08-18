# tmux cheat sheet

Your setup: every new terminal auto-attaches to the shared **home** session.
The "prefix" is **Ctrl-b** — press it, release, then press the next key.

## The dashboard (panes)

| Do this                    | How                                      |
|----------------------------|------------------------------------------|
| Split side-by-side         | `Ctrl-b` then `\|`                        |
| Split top/bottom           | `Ctrl-b` then `-`                         |
| Move between panes         | click a pane, or `Ctrl-b` then an arrow key |
| Resize a pane              | drag the border with the mouse, or `Ctrl-b` then `Option+arrow` |
| Zoom a pane full-screen    | `Ctrl-b` then `z` (again to un-zoom)      |
| Close a pane               | type `exit` (or `Ctrl-d`)                 |
| Scroll back                | mouse wheel; `q` to jump back to live     |

Note: `Option+arrow` on its own does **not** switch panes — this iTerm profile sends
it to your shell as jump-one-word-left/right. Pane moves always need the `Ctrl-b`
prefix first (or just click).

## Sessions (your workspaces — survive closing the window)

| Do this                        | How                                  |
|--------------------------------|---------------------------------------|
| Detach (leave everything running) | `Ctrl-b` then `d`                  |
| Come back                      | open any terminal (auto-attaches), or `tmux attach -t home` |
| List sessions                  | `tmux ls`                             |
| Switch session (picker)        | `Ctrl-b` then `s`                     |
| New named session              | `tmux new -s projectname`             |

## Misc

| Do this                    | How                                      |
|----------------------------|-------------------------------------------|
| Reload config after edits  | `Ctrl-b` then `r`                         |
| Rename current session     | `Ctrl-b` then `$`                         |
| Copy text                  | hold `Option` while dragging (iTerm), or drag-select normally and it auto-copies |

**The one habit to build:** stop closing terminal windows to "clean up" — detach
(`Ctrl-b d`) instead. Everything keeps running and is there when you come back.

Config lives at `~/.tmux.conf`. This file: `~/tmux-cheatsheet.md` (delete anytime).
