# karabiner

Every Karabiner-Elements remap this machine runs, generated from one compact
spec file.

PC-style text editing (`Ctrl+C/V/X`, `Ctrl+Arrow` word navigation,
`Ctrl+Backspace` delete-word, `Ctrl+Tab` and `Ctrl+1..9` tab switching), the
`fn+F7/F8` volume keys, and the function key row.

**Terminals are excluded from every text-editing remap here**, so `Ctrl+C`
still sends SIGINT in Alacritty, and tmux and Neovim bindings are untouched.
The exceptions are the two groups that are not text editing — the volume keys
and the function key row — which fire everywhere, because a media key means
the same thing in a terminal as anywhere else. zathura is
excluded on the same grounds — it is vim-keyed, and `Ctrl+R`, `Ctrl+D` and
`Ctrl+F` mean recolor and scrolling there, not reload and find. Wherever this
file says "not in terminals" below, read it as "not in terminals or zathura".

That exclusion is total on purpose, word navigation and delete-word included.
They were briefly mapped everywhere, on the theory that `Option+Arrow` and
`Option+Backspace` are useful in a shell. They are not, in this one: Alacritty
leaves `option_as_alt` at `None` on macOS, so `Option+Arrow` arrives as a bare
arrow and `Option+Backspace` as a bare delete. The rewrite was taking a working
chord and returning a broken one.

## The function key row

Neovim binds `<F7>` to its floating terminal and it did nothing, on the
built-in keyboard *and* on the Glove80. The cause sits below this file
entirely.

macOS draws the media functions over the top row of **Apple** keyboards.
Karabiner grabs every physical keyboard and re-emits events through its own
virtual device, and that device reports Apple's vendor id (`1452`) — so the
overlay is applied to everything Karabiner passes on, the Glove80 included,
whose `f7` was correct the whole time. The overlay is *downstream* of
Karabiner, which is why nothing here could win it: a complex modification from
`f7` to `f7` did nothing, and neither did the `fn_function_keys` table. Both
measured, not assumed.

The only switch upstream of it is the macOS setting, so `macos/defaults.sh`
sets `com.apple.keyboard.fnState`. That is heavy-handed on its own — it takes
the whole row away from a bare press for the sake of one key — so the
`the media row on a bare press, except F7` group here puts every one of them
back explicitly, `f7` excepted. With the overlay off Karabiner is no longer
competing with macOS for the row; it is the only thing assigning it.

The two halves are load-bearing together. `fnState` without these rules leaves
the row dead; these rules without `fnState` do nothing at all.

`F7` is then split back apart along the same line every other rule here uses:
previous-track outside terminals, a raw `F7` inside them. The app is the axis
that matters, not the keyboard — scoping it to the built-in keyboard instead
would kill previous-track on the Glove80, fixing one keyboard by breaking the
other. Same known gap as the `Ctrl+letter` rules: VS Code's integrated terminal
reads as VS Code, so it gets previous-track rather than `F7`.

Cost: `fn+F1..F12` now produce literal function keys rather than media — the
inverse of stock, and what keeps `fn+F7` free for the volume rule.

Left alone, the terminal's own path works end to end:

| Chord | What carries it |
|---|---|
| `Ctrl+Left/Right` | Alacritty sends `^[[1;5C/D`; oh-my-zsh binds both to word motion |
| `Ctrl+Delete` | Alacritty sends `^[[3;5~`; oh-my-zsh binds it to `kill-word` |
| `Ctrl+Backspace` | `alacritty.toml` sends `^W`; terminals cannot tell it from a plain backspace, so it needs the explicit binding |
| `Ctrl+Shift+C/V` | `alacritty.toml`, copy and paste |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | `alacritty.toml`, font zoom |

`^W` is also what makes `Ctrl+Backspace` work *inside* tmux. tmux's
command-prompt (the `rename-window` line) binds `C-w` to `delete-word` and binds
Meta-Backspace to nothing at all, measured rather than assumed, so `^W` is the
only payload that deletes a word there.

The last three are Alacritty defaults on Linux and Windows but not on macOS,
which is why they have to be declared.

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
| `F1`–`F6`, `F8`–`F12` (bare) | brightness, mission control, spotlight, dictation, do-not-disturb, media, volume | everywhere |
| `F7` (bare) | previous track | not in terminals |
| `F7` (bare) | a real `F7` — Neovim's floating terminal | terminals only |
| `fn+F7` / `fn+F8` | volume down / up | everywhere |
| `Ctrl+C/V/X/Z/A/B/I/F/G/S/P/T/W/N/R` | `Cmd+` same | not in terminals |
| `Ctrl+Y` | `Cmd+Shift+Z`, redo | not in terminals |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | zoom in / out / reset | not in terminals |
| `Ctrl+Left/Right` (`+Shift`) | `Option+Left/Right` | not in terminals |
| `Ctrl+Backspace` / `Ctrl+Delete` | `Option+` same | not in terminals |
| `Ctrl+Home` / `Ctrl+End` (`+Shift`) | `Cmd+Up` / `Cmd+Down` | not in terminals |
| `Home` / `End` (`+Shift`) | `Ctrl+A` / `Ctrl+E`, line start / end | not in terminals or VS Code |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | `Cmd+Option+Right/Left` | not in terminals |
| `Ctrl+PageDown` / `Ctrl+PageUp` | same, next / previous tab | not in terminals |
| `Ctrl+1`..`Ctrl+9` | `Cmd+1`..`Cmd+9` | not in terminals |
| `Ctrl+L` / `Ctrl+D` | address bar / bookmark | browsers only |
| `Ctrl+H` / `Ctrl+J` | history / downloads | browsers only |
| `Ctrl+U` / `Ctrl+Shift+I` / `Ctrl+Shift+J` | source / devtools / console | browsers only |
| `Ctrl+Shift+R` / `Ctrl+Shift+Backspace` | hard reload / clear data | browsers only |

Three of those emit a different key than they take, because Windows and macOS
disagree on the letter. `Ctrl+Y` sends `Cmd+Shift+Z`, since macOS `Cmd+Y` is
History rather than redo. `Ctrl+H` sends `Cmd+Y`, since `Cmd+H` would hide the
app. `Ctrl+J` sends `Cmd+Shift+J`, which is where Chrome keeps Downloads.

`Shift` in brackets means the mapping carries Shift through, so `Ctrl+Shift+Z`
is redo and `Ctrl+Shift+T` reopens a closed tab without needing their own rules.

Either Control key triggers these. The mappings used to require `left_control`,
which meant they silently did nothing for anyone reaching for the right-hand
Control key. `control` in `spec.json` matches both. If you ever want a raw
`Ctrl+key` that no rule swallows, narrow the specific mapping back to
`left_control` and use the right key as the escape hatch.

### Per-keyboard: the Glove80's Super key drives AeroSpace

On Arch, i3's mod key is the Windows/Super key. AeroSpace's mod is `alt`, so on
the Glove80 that muscle memory lands on the wrong key. The `glove80` scope fixes
it by swapping Command and Option **on that keyboard only**, matched by
`vendor_id 5824, product_id 10203`. The built-in MacBook keyboard is untouched
and keeps Option as the AeroSpace mod, which is what it has always been.

No toggle, no second profile, no Raycast script: Karabiner keys off the device
the event came from, so plugging the Glove80 in or walking away from it is the
whole switch.

Three things worth knowing about it:

- It is a **swap**, not a one-way map. Mapping Command to Option alone would
  leave the Glove80 with no Command key at all, so `Cmd+Space`, `Cmd+Tab` and
  `Cmd+Q` would be untypable from it. After the swap, Command lives at the
  Alt position on that board. That asymmetry between keyboards is inherent to
  wanting Super as the mod on one of them.
- It applies to **every** Option shortcut on that keyboard, not only AeroSpace's.
  Anything an app binds to Option wants the Super-position key there instead,
  and it is easy to mistake that for a broken app rather than a moved key. A
  second group, `Glove80 in browsers`, buys back the four that are used daily
  (see below). Everywhere else on that board, press Super where you would have
  pressed Alt.
- Both sides are swapped, left and right. The board's layout is non-standard
  (its Ctrl reports as `right_control`), so which side its Super key uses is not
  worth assuming.
- `optional: ["any"]` on all four mappings is load-bearing. Without it the
  modifier only matches when nothing else is held, which silently breaks every
  `Super+Shift` chord: AeroSpace's move-window and move-to-workspace bindings.

Doing this in the Glove80's ZMK firmware instead would be cleaner in one sense,
but the board is Bluetooth and also pairs with the Arch box, where i3 wants that
same physical key to stay Super. Firmware fixes one host by breaking the other.
Karabiner is per-machine, so the keyboard keeps sending Super and only macOS
reinterprets it.

Get the identifiers for another keyboard with:

```sh
karabiner_cli --list-connected-devices
```

### Per-keyboard and per-app: giving the Glove80's Alt key back

The swap above puts Command at the Alt position, which is correct for AeroSpace
and wrong for the handful of app shortcuts that are reached by Alt on every
other platform. The `Glove80 in browsers` group undoes it for exactly those,
scoped to `["glove80", "browsers"]` so it needs both the keyboard **and** a
browser to be frontmost:

| Pressed on the Glove80 | Karabiner emits | Who wants it |
|---|---|---|
| `Alt+Shift+D` | `Option+Shift+D` | Dark Reader toggle |
| `Alt+[` / `Alt+]` | `Option+[` / `Option+]` | `claude.js` previous/next message |
| `Alt+E` | `Option+E` | `claude.js` edit nearest message |

One more, outside browsers, in the `Glove80 outside VS Code` group:

| Pressed on the Glove80 | Karabiner emits | Who wants it |
|---|---|---|
| `Ctrl+Shift+X` | `Option+Shift+X` | AeroSpace `alt-shift-x`, dismiss notification banners |
| `Ctrl+Shift+N` | `Option+Shift+N` | AeroSpace `alt-shift-n`, open Notification Center |

That group sits above the `Ctrl+letter to Cmd+letter` block on purpose, since the
`x` rule there takes shift as optional and would otherwise claim the chord first.
`not_vscode` keeps the Extensions view and New Window intact where they belong.
Cost outside VS Code on that keyboard: `Cmd+Shift+N`, a new incognito window in
browsers. `alt-i` already opens one, and the Option-position key still sends
Command, so `Option+Shift+N` gets it back anyway.

The AeroSpace bindings stay regardless of keyboard, because they are what
actually runs the scripts; this group only rewrites the chord into one AeroSpace
already answers.

The result is one gesture on both keyboards: the key labelled Alt, in a browser,
does the Alt thing. The userscript itself is untouched and still keys off plain
Option, which is what the MacBook keyboard sends.

This is why a `scope` may be a list. Karabiner ANDs every entry in a
manipulator's `conditions` array, so `["glove80", "browsers"]` is a
concatenation of the two condition blocks. `null` is rejected inside a list: it
contributes nothing but reads as though it widens the scope.

What it costs, on the Glove80 in browsers only: `Cmd+[` / `Cmd+]` back and
forward (use `Alt+Left` / `Alt+Right`, which the swap turns into `Cmd+Arrow`),
`Cmd+E`, and `Cmd+Shift+D` bookmark-all-tabs. All three are reachable from the
menu bar and none is a daily chord.

`Option+Shift+D` also had to be freed on the AeroSpace side: bindings there are
global and consume the chord, so `alt-shift-d` was eating Dark Reader on **both**
keyboards. It is now `alt-shift-c`.

The same shape, one chord wide, exists for VS Code. `vscode/keybindings.json`
binds `ctrl+alt+c` to `notebook.cellOutput.copy`, and that file is shared with
Arch, so the fix cannot live there:

| Pressed on the Glove80 | Karabiner emits | Who wants it |
|---|---|---|
| `Ctrl+Alt+C` | `Ctrl+Option+C` | `notebook.cellOutput.copy`, copy a cell's output |

Scoped `["glove80", "vscode"]`. It cannot disturb the `Ctrl+letter to Cmd+letter`
group: that rule takes control as mandatory and shift as optional, so a held
Command already means no match, and plain `Ctrl+C` still becomes `Cmd+C`. Ctrl
plus the Command-position key keeps working too, because the swap already turns
it into `ctrl+alt+c` before any rule sees it. Cost, on the Glove80 in VS Code
only: `Ctrl+Cmd+C`, which nothing binds.

### Chords deliberately left alone

Something else already owns these, and mapping them would swallow the event
before that something ever sees it:

| Chord | Owner |
|---|---|
| `ctrl+shift+r` | `vscode/keybindings.json` — run all notebook cells |

`r` is handled by scope rather than by omission: plain `Ctrl+R` is reload in the
`gui` scope, and `Ctrl+Shift+R` is hard reload in the `browsers` scope only, so
VS Code still gets its own `ctrl+shift+r`. The same split keeps `Ctrl+Shift+I`
browser-only while plain `Ctrl+I` is italic, and `Ctrl+Shift+Backspace`
browser-only while plain `Ctrl+Backspace` is delete-word.

Three chords used to be on that list and are not any more. Each was an AeroSpace
launcher sitting on a chord that VS Code wants, and in every case the VS Code
meaning won, because no other platform uses those chords for a launcher:

| Chord | Now does | The AeroSpace binding moved to |
|---|---|---|
| `ctrl+shift+p` | command palette | `alt-i` — Brave incognito |
| `ctrl+shift+d` | Run and Debug | `alt-shift-c` — cancel a drag-mac drag |
| `ctrl+shift+x` | Extensions, in VS Code only | `alt-shift-x` — dismiss notifications |

AeroSpace now has no `ctrl` bindings at all, which is worth keeping that way:
every launcher on the `alt` mod means the Glove80's Super key reaches all of
them, and it leaves the whole `ctrl+shift+` space free for applications.

Known collision, pre-existing: `ctrl+shift+c` in VS Code (clear all notebook
outputs) never fires, because `c` carries Shift through to `Cmd+Shift+C`. Drop
the `optional` on `c` if you want that binding back, at the cost of
`Ctrl+Shift+C` inspect-element in browsers.

Plain `Home`/`End` go to line start/end, but via `Ctrl+A`/`Ctrl+E`, not via
`Cmd+Left`/`Cmd+Right`. That choice is the whole point of the mapping. macOS
puts line-start on `Cmd+Left`, which is also Back in a browser, so a `Home` that
emitted it would navigate off the page whenever focus was not in a text field.
`Ctrl+A`/`Ctrl+E` are the Cocoa and Chromium editing bindings: they move the
caret in a text field and do nothing at all outside one, so the failure mode is
silence rather than losing your page.

Two consequences worth knowing:

- Outside a text field, `Home` no longer scrolls to the top of the page, which
  is what stock macOS did with it. Document-top is `Ctrl+Home`, which is where
  Windows and Linux put it anyway.
- VS Code is excluded, via `["gui", "not_vscode"]`. It already implements PC
  `Home`/`End` natively on macOS, including the Shift variants for selection.
  Mapping them there would take a chord that works and hand it `Ctrl+Shift+A`,
  which has no default binding. Same mistake as rewriting terminal chords.

`Shift` carries through, so `Shift+Home` extends the selection to line start.

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
- `gui` — `unless` the listed terminals, plus zathura (the default)
- `browsers` — `if` one of the listed browsers

Add your own by adding a key to `scopes` and referencing it from a group.

### Apps with no bundle identifier

A bundle identifier only exists for a real `.app`. A bare unix binary has none,
so **no `bundle_identifiers` denylist can ever exclude one** — it will always
fall through and get the mapping.

zathura is the case that bit. Homebrew installs it as `/opt/homebrew/bin/zathura`
with no bundle at all, so the `gui` denylist did not cover it and every
`Ctrl+letter` chord was rewritten to `Cmd+letter`. zathura is vim-keyed, so that
broke `Ctrl+R` (recolor), `Ctrl+D`/`Ctrl+U` (half-page scroll) and
`Ctrl+F`/`Ctrl+B` (full page) all at once.

The escape hatch is `file_paths`, a sibling of `bundle_identifiers` on any app
scope. It is a list of regexes matched against the frontmost application's
executable path, and Karabiner joins every entry across **both** lists with
`or`, so one `unless` scope can deny by either:

```json
"gui": {
  "mode": "unless",
  "bundle_identifiers": ["^io\\.alacritty$", "..."],
  "file_paths": ["/zathura$"]
}
```

Anchor on the basename, not the full path. zathura is launched three ways here
(directly, via `zp`, via `online-zathura`), and the Homebrew symlink and the
resolved Cellar path differ — the latter carrying a version number that changes
on upgrade.

Check whether an app has a bundle id before assuming it does:

```sh
osascript -e 'id of app "zathura"'   # errors — there is no app to ask about
```

Karabiner-EventViewer's Frontmost Application tab shows both fields, and is the
honest answer when `osascript` cannot find the app at all.

Scoping cannot see inside an app: tmux inside Alacritty reads as Alacritty,
which is what you want, but VS Code's integrated terminal reads as VS Code, so
the letter remaps do apply in that pane. `Ctrl+C` arrived there as `Cmd+C` and
never reached the shell, so it could not interrupt anything.

That one is fixed, but not here. `vscode/keybindings.json` translates the six
chords a shell actually needs back into their control characters, gated on
`when: terminalFocus`, which is the only condition in the whole stack that can
tell the terminal panel from the editor. Karabiner has no equivalent. Anything
else that embeds a terminal will have the same problem and needs the same kind
of app-side fix.

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

**I added it to the denylist and it still fires.** Check whether the app has a
bundle identifier at all. If `osascript -e 'id of app "name"'` errors, it is a
bare binary and `bundle_identifiers` cannot match it — deny it by `file_paths`
instead. See [Apps with no bundle identifier](#apps-with-no-bundle-identifier).
