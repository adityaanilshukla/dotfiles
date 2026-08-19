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
- `trash-cli`, for `dT`. On macOS Homebrew this formula is **keg-only**, so
  `brew install` never links it, and `rc.conf` calls `trash-put` by its full
  keg path so the binding does not depend on shell startup at all. macOS also
  ships its own unrelated `/usr/bin/trash`, which is the collision that makes
  the formula keg-only in the first place. `zsh/zshrc` separately prepends
  `/opt/homebrew/opt/trash-cli/bin` so the commands are reachable by name in an
  interactive shell; that is what makes `rifle.conf`'s `has trash-put` branch
  match, and it deliberately shadows `/usr/bin/trash`. `rc.conf` keeps the full
  path regardless, since it is the more robust form.

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
| `r` | Stock open-with picker. Names that work on any file: `nvim`, `editor`, `pager`, `open`, `brave`, `trash`. On any format zathura can open (pdf, epub, mobi, fb2, oxps) the list also includes `zp`, which opens it with no reading state stored (see `rifle.conf`). The list ranger draws shows each rule's command, never its label, so the row reads `3 \| "$HOME/.local/bin/zp" "$@"` and gives no hint that `zp` is a name you can type. Both the label and the number work. |
| `<C-r>` | `reset`. Re-reads `rifle.conf`, which nothing else does; see Notes. |
| `cW` | Rename via sudo |
| `dT` | Move selection to trash |
| `gT` | cd to trash dir |
| `g{P,C,S,e,M,p,D,b,l,i,…}` | Quick-cd shortcuts, see `rc.conf` for the full list |

## Notes

- **An unconditioned rule becomes the default for every file.** rifle takes
  the first matching rule as the default action, so a rule with no `ext` or
  `mime` condition, placed early, wins for everything. The Brave rule was
  written that way, at the top, purely so `r` then `brave` would work on any
  file. The side effect was that plain Enter opened Brave for markdown, python,
  json and plain text. Label-only openers belong at the bottom of the file
  where they cannot win a default; `nvim`, `brave` and `zp` all live there now.

- **Neither `$EDITOR` nor `$VISUAL` is guaranteed to be set.** `zsh/zshrc`
  exports both, but the `alt-n` launcher is `open -na Alacritty --args ... -e
  ranger`, which execs ranger with no shell in between, so zshrc never runs.
  Measured on a clean launch: no EDITOR, no VISUAL, no PAGER, and `PATH` is
  just `/usr/bin:/bin`, which has no nvim in it either. The stock
  `${VISUAL:-$EDITOR} -- "$@"` then expands to `-- somefile` and opening a text
  file silently does nothing. The rules here fall back to nvim's full bob path,
  same reasoning as `rc.conf` calling `trash-put` by full keg path.

- **A label only exists for files a rule matches.** rifle considers only the
  rules whose conditions fit the selected file, so `r` then `zp` on an epub
  reported `Label 'zp' is undefined` for as long as the rule read `ext pdf`.
  The message is easy to misread: it means undefined *for this file*, not
  undefined in the config. When a label works on one file type and not another,
  check the rule's `ext` list before anything else.

- **`rifle.conf` is read once, at startup.** ranger builds its Rifle object in
  `core/fm.py` and calls `reload_config()` there and nowhere else; neither
  `Rifle.execute` nor `list_commands` ever re-reads the file. So a ranger
  window that was already open when `rifle.conf` changed keeps serving the
  rules it parsed at launch, for as long as that window lives. Editing the file
  changes nothing in it, and neither does `R`, which is bound to `reload_cwd`
  here and does not touch rifle.

  This is what bit `dT` once: it was reported broken against a long-lived
  ranger that predated the fix, and it "fixed itself" when that window was
  eventually restarted. Worth ruling out early, but rule it out by restarting
  and retrying, not by assuming, since a rule that never matched the file in
  the first place looks identical from the outside.

  `Ctrl+R` (`reset`) re-reads it in place. Reach for that after editing
  `rifle.conf`, and after any branch switch, since `~/.config/ranger` is a
  symlink into this repo and the checked-out branch *is* the live config. The
  `post-checkout` hook warns about the branch half of that; nothing can warn
  about the already-running-window half.

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
