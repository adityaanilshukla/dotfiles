# karabiner

Every Karabiner-Elements remap this machine runs, generated from one compact
spec file.

PC-style text editing (`Ctrl+C/V/X`, `Ctrl+Arrow` word navigation,
`Ctrl+Backspace` delete-word, `Ctrl+Tab` and `Ctrl+1..9` tab switching) plus the
`fn+F7/F8` volume keys.

**Terminals are excluded from the letter remaps**, so `Ctrl+C` still sends
SIGINT in Alacritty, and tmux and Neovim bindings are untouched. Word navigation
and delete-word are deliberately *not* excluded — they are useful in a shell and
collide with nothing.

## Install

```sh
./install.sh
```

Idempotent, run it as often as you like. The top-level `install.sh` runs it too,
after `brew bundle`. First run on a new machine also needs manual permission
grants and a reboot; the script prints the checklist.

## Layout

```
spec.json           source of truth — edit this
generate.py         spec.json -> rules/managed.json
rules/managed.json  generated, committed so a fresh clone works
install.sh          generates, symlinks, merges into karabiner.json
verify.sh           what is actually live right now
```

Karabiner needs a `conditions` block on every individual manipulator, so app
scoping has to be repeated on all 40-odd mappings. `spec.json` keeps the
readable version and `generate.py` produces the verbose one.

## What is mapped

| Chord | Becomes | Where |
|---|---|---|
| `fn+F7` / `fn+F8` | volume down / up | everywhere |
| `Ctrl+C/V/X/Z/Y/A/F/G/S/P/T/W/N/R` | `Cmd+` same | not in terminals |
| `Ctrl+Left/Right` (`+Shift`) | `Option+Left/Right` | everywhere, terminals included |
| `Ctrl+Backspace` / `Ctrl+Delete` | `Option+` same | everywhere |
| `Ctrl+Home` / `Ctrl+End` (`+Shift`) | `Cmd+Up` / `Cmd+Down` | not in terminals |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | `Cmd+Option+Right/Left` | not in terminals |
| `Ctrl+1`..`Ctrl+9` | `Cmd+1`..`Cmd+9` | not in terminals |
| `Ctrl+L`, `Ctrl+Shift+I/J` | address bar, devtools | browsers only |

`Shift` in brackets means the mapping carries Shift through, so `Ctrl+Shift+Z`
is redo and `Ctrl+Shift+T` reopens a closed tab without needing their own rules.

Either Control key triggers these. The mappings used to require `left_control`,
which meant they silently did nothing for anyone reaching for the right-hand
Control key. `control` in `spec.json` matches both. If you ever want a raw
`Ctrl+key` that no rule swallows, narrow the specific mapping back to
`left_control` and use the right key as the escape hatch.

### Chords deliberately left alone

Something else already owns these, and mapping them would swallow the event
before that something ever sees it:

| Chord | Owner |
|---|---|
| `ctrl+shift+p` | `aerospace.toml` — Brave incognito window |
| `ctrl+shift+r` | `vscode/keybindings.json` — run all notebook cells |
| `ctrl+shift+x` | `aerospace.toml` — dismiss notifications |
| `ctrl+shift+d` | `aerospace.toml` — cancel a drag-mac drag |

That is why `p` and `r` have no `optional: ["shift"]` in `spec.json` while `t`,
`w` and `n` do.

Known collision, pre-existing: `ctrl+shift+c` in VS Code (clear all notebook
outputs) never fires, because `c` carries Shift through to `Cmd+Shift+C`. Drop
the `optional` on `c` if you want that binding back, at the cost of
`Ctrl+Shift+C` inspect-element in browsers.

Plain `Home`/`End` are **not** remapped to line start/end. In a browser outside
a text field, `Cmd+Left` is Back, so `Home` would navigate away from the page
instead of scrolling to the top. Add a group scoped to a specific editor if you
want it somewhere narrow.

## Changing the keymap

Edit `spec.json`, then:

```sh
./install.sh
```

Karabiner watches `karabiner.json` and hot-reloads. No restart.

### Adding an app

Add its bundle id to the relevant entry in `scopes`. Find the id with:

```sh
osascript -e 'id of app "Obsidian"'
```

Or open Karabiner-EventViewer, Frontmost Application tab.

`scopes` is a named map, and each group picks one by name:

- `everywhere` — no condition at all
- `gui` — `unless` the listed terminals (the default)
- `browsers` — `if` one of the listed browsers

Add your own by adding a key to `scopes` and referencing it from a group.

Scoping cannot see inside an app: tmux inside Alacritty reads as Alacritty,
which is what you want, but VS Code's integrated terminal reads as VS Code, so
the letter remaps do apply in that pane.

## How enabling works

Dropping a file in `~/.config/karabiner/assets/complex_modifications/` only
makes it *importable* in the GUI. Actually enabling it means copying the rule
objects into `profiles[N].complex_modifications.rules` in `karabiner.json`.
`install.sh` does that merge with jq.

Rules are keyed by the `prefix` in `spec.json` (`dotfiles: `). Each run drops
every rule with that prefix and appends the current set, so re-running replaces
rather than duplicates, and deleting a group from `spec.json` removes it on the
next run. Anything you add by hand in the GUI has no prefix and is left alone.

`karabiner.json` is **not** symlinked into this repo, and is not tracked here at
all. It used to be both. Two reasons it stopped:

1. The settings GUI rewrites that file with UI state, so tracking it means
   endless spurious diffs.
2. `install.sh` writes to it. With the symlink in place, every install run would
   dirty the working tree.

Nothing is lost by not tracking it: `spec.json` reproduces every rule, and
`install.sh` writes a minimal valid config on a machine that has never launched
Karabiner. Backups go to `~/.config/karabiner/backups/`, last 10 kept.

## Verify

```sh
./verify.sh
```

Prints the driver-extension state, whether `karabiner.json` is a real file, and
every live rule tagged `[managed]` or `[manual]`.

## Troubleshooting

**Nothing happens.** The driver extension isn't active. Check with
`systemextensionsctl list | grep -i karabiner` — you want `[activated enabled]`.
Otherwise: System Settings > General > Login Items & Extensions > Driver
Extensions, plus Privacy & Security > Input Monitoring for both
`karabiner_grabber` and `Karabiner-Elements`. Reboot.

**Changes get reverted.** The Karabiner settings window was open during the
merge and wrote its stale in-memory state back. Quit it and re-run.
`install.sh` quits it automatically.

**A shortcut fires in the wrong app.** Wrong bundle id, or the regex is too
loose. `^com\.brave\.Browser` intentionally has no `$` so it matches Brave Beta
and Nightly too. Confirm the live value in Karabiner-EventViewer.

**Ctrl+C stopped working in my terminal.** Your terminal is missing from the
`gui` scope's denylist in `spec.json`.
