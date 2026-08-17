# ranger config

My personal [ranger](https://github.com/ranger/ranger) configuration. Part of the
dotfiles repo; `install.sh` symlinks this directory to `~/.config/ranger`, so
edits here are live immediately with no copy step.

## Install

Nothing to do separately. Clone the dotfiles repo and run `./install.sh`.

The devicons plugin is vendored directly into `plugins/ranger_devicons`, not a
submodule, so no `--recurse-submodules` or `submodule update` is needed.

## Dependencies

All of these come from the repo `Brewfile` on macOS. On Linux, install the
equivalents through the distro package manager.

Required:

- `ranger`
- A Nerd Font in the terminal, for the devicons glyphs
- `trash-cli`, for `dT`. On macOS Homebrew this formula is **keg-only**, so its
  binaries are never linked onto PATH and `rc.conf` calls `trash-put` by its
  full keg path. macOS also ships its own unrelated `/usr/bin/trash`.

Clipboard backend for `yp` / `yd` / `yn` / `y.`:

- macOS: `pbcopy`, built in
- X11: `xclip`; Wayland: `wl-clipboard`

For `dn` (drag and drop), platform-specific:

- macOS: `drag-mac`, in this repo under `drag-mac/`. Needs a Python venv with
  PyObjC, which `install.sh` builds at `~/.local/share/drag-mac/venv`.
- Linux: `dragon-drop` (Arch AUR: `paru -S dragon-drop`). X11 only.

Optional:

- `zathura` for PDFs, `mpv` for video

## Custom keybindings

| Key | Action |
| --- | --- |
| `yp` / `yd` / `yn` / `y.` | Yank path / dir / name / name-without-ext to clipboard, with statusbar notification |
| `dn` | Drag the selection out to another app |
| `r` | Stock open-with picker. For a PDF the list includes `zp`, which opens it in zathura with no reading state stored (see `rifle.conf`). |
| `cW` | Rename via sudo |
| `dT` | Move selection to trash |
| `gT` | cd to trash dir |
| `g{P,C,S,e,M,p,D,b,l,i,…}` | Quick-cd shortcuts, see `rc.conf` for the full list |

## Notes

- The `yank` command in `commands.py` overrides the stock one. It notifies on
  success and, inside tmux, falls back to tmux's server-global `DISPLAY` /
  `XAUTHORITY` when the ranger process's own env lacks them, which happens in
  panes that predate the X session.
- The `drag` command picks its tool by platform. Linux detaches with
  `setsid -f`; macOS ships no `setsid(1)` at all, so it detaches with
  `start_new_session`, the same syscall. The macOS launcher is invoked by
  absolute path because `Popen` resolves bare names against ranger's own PATH,
  which is whatever `open -na Alacritty` handed it and does not include
  `~/.local/bin`.
- On macOS the drag window closes itself once a drop lands. `Escape` closes it
  when focused, and `alt-shift-c` (aerospace) closes it from anywhere, which
  matters because after a drag the destination app holds focus. `q` is
  deliberately not bound: if the window is not really focused, `q` quits ranger.
