# ranger-config

My personal [ranger](https://github.com/ranger/ranger) configuration.

## Install

Clone into `~/.config/ranger`, pulling the devicons submodule along the way:

```bash
git clone --recurse-submodules https://github.com/adityaanilshukla/ranger-config ~/.config/ranger
```

If you already cloned without `--recurse-submodules`:

```bash
git -C ~/.config/ranger submodule update --init
```

## Dependencies

Required:

- `ranger`
- `xclip` (X11) or `wl-clipboard` (Wayland) — clipboard backend for `yp` / `yd` / `yn` / `y.`
- A Nerd Font in your terminal — needed for the devicons plugin glyphs

Optional:

- `dragon-drop` (Arch AUR: `paru -S dragon-drop`) — needed for the `dn` drag-and-drop binding
- `zathura` — PDFs open detached via the `mime` rule in `rc.conf`
- `mpv` — mp4 playback
- `trash-cli` — for `dT` (move selection to trash)

## Custom keybindings

| Key | Action |
| --- | --- |
| `yp` / `yd` / `yn` / `y.` | Yank path / dir / name / name-without-ext to clipboard, with statusbar notification |
| `dn` | Drag-and-drop selection out via dragon-drop |
| `cW` | Rename via sudo |
| `dT` | trash-put selection |
| `gT` | cd to trash dir |
| `g{P,C,S,e,M,p,D,b,l,i,…}` | Quick-cd shortcuts — see `rc.conf` for the full list |

## Notes

- The `yank` command in `commands.py` overrides the stock one. It notifies on success and, when running inside tmux, falls back to tmux's server-global `DISPLAY` / `XAUTHORITY` if the ranger process's own env is missing them — which happens in panes that predate the X session.
- The `drag` command uses `setsid -f` so dragon-drop is fully detached from ranger.
