# Setting up a new Mac

## The short version

```sh
# 1. Xcode Command Line Tools
xcode-select --install

# 2. SSH key, and add it to GitHub. Do this BEFORE step 3: install.sh clones
#    the nvim config and online-zathura over SSH and will skip them otherwise.
ssh-keygen -t ed25519 -C "adityaanilsindhunath@gmail.com"
pbcopy < ~/.ssh/id_ed25519.pub     # paste into github.com/settings/keys

# 3. Clone the macOS branch. `main` is the Linux branch and has no install.sh.
git clone -b MacOS git@github.com:adityaanilshukla/dotfiles.git ~/dotfiles

# 4. Run it. Idempotent, so re-run freely if something fails partway.
cd ~/dotfiles && ./install.sh
```

## What install.sh does

Installs Homebrew and everything in the `Brewfile` (~80 packages), then:

- **Neovim** — `bob use nightly` for the binary, and clones the config from
  `github.com/adityaanilshukla/nvim` into `~/.config/nvim`. The config is a
  separate repo, so without this you get nvim and no config.
- **Non-brew tooling** — rustup, pipx apps (`nbstripout`, `otpfetch`), and
  `eslint_d` via npm. None of these can come from a Brewfile.
- **online-zathura** — clones and builds it into `~/.local/bin`.
- **Karabiner** — generates the keyboard remaps from `karabiner/spec.json` and
  merges them into `~/.config/karabiner/karabiner.json`. That file is generated,
  not symlinked, so it is the one config here that does not live in the repo.
  Non-fatal: if the driver permissions aren't granted yet the module says so and
  the rest of the setup continues.
- **drag-mac** — builds the PyObjC venv behind ranger's `dn` binding, then
  self-tests it. Self-healing: a Homebrew python upgrade breaks a venv, so it
  checks whether the venv can actually import its frameworks, not merely
  whether the directory exists.
- **Alacritty font size** — writes `~/.config/alacritty/font-size.toml` to suit
  the screen currently attached. `alacritty.toml` sets no size of its own, it
  imports that file, so without this step alacritty falls back to its own
  default of 11.25 and every terminal is unreadably small. Regenerated
  afterwards by sketchybar whenever a monitor is plugged in or unplugged.
- **Symlinks** every tracked config into place, and the git hooks.
- **Starts** the sketchybar and syncthing services.
- **VS Code extensions** and the macOS `defaults`.

## Manual steps afterwards

`install.sh` prints these too. Nothing can automate them.

| Step | Why |
|---|---|
| Open AeroSpace once | Installing a cask does not launch it, and `start-at-login` only registers after a first run. This also raises the Accessibility prompt. |
| Grant **Accessibility** to AeroSpace, Karabiner, BetterDisplay, Raycast | AeroSpace cannot tile without it, and `alt-shift-x` (dismiss notifications) needs it. |
| Approve the **Karabiner driver extension** and its Input Monitoring, then reboot | Nothing remaps until the DriverKit extension is `activated enabled`. `karabiner/install.sh` prints the exact panes; `karabiner/verify.sh` confirms. |
| Approve the **macfuse** kernel extension, then reboot | Kernel extensions require explicit approval. |
| `gh auth login` | per-device auth |
| `tailscale up` | per-device auth; links this machine to `brovo` |
| `make -C ~/Projects/online-zathura join` | mints this device's Turso token for reading-state sync |
| Import your **GPG key**, then `scripts/secrets.sh decrypt` | The private key is deliberately not in this repo. Without it `secrets.gpg` cannot be opened. |
| Install the Raycast extension **Set Audio Device** (`benvp/audio-device`): `open 'raycast://extensions/benvp/audio-device'` | AeroSpace's `alt-ctrl-z` and the sketchybar audio glyph both deeplink into it. Until it is installed, both silently do nothing. |
| Import `vimium_c-*.json` into **Vimium C** (Options > Backup and restore) | The extension stores its settings in browser storage. The file in this repo is a backup, not a live config. |
| Set **Dark Reader** to `Alt+Shift+D` in `about:addons` > Manage Extension Shortcuts | Browser extension shortcuts live in the Firefox profile, not on disk. `karabiner/spec.json` routes the Glove80's Alt key to that chord, but the chord itself has to be registered here first. |
| Paste the **Tampermonkey** userscripts from `~/Projects/tampermonkey` | Tampermonkey stores its own copy in browser storage. There is no `@require file://`, so editing the files on disk changes nothing until you copy them across. `claude/claude.js` is the one the Glove80 Alt chords drive. |

## Things worth knowing

**The checked-out branch is your live config.** `~/.config/ranger`,
`~/.config/aerospace` and `~/.config/sketchybar` are symlinks into this repo, so
switching branches silently reconfigures the file manager, the window manager
and the status bar. A `post-checkout` hook warns when HEAD leaves `MacOS`. Stay
on `MacOS` for day-to-day work.

**Re-running install.sh on an established machine is not the same as a fresh
install.** Homebrew casks try to *adopt* apps you installed by hand, which needs
a `sudo` password and fails non-interactively. Observed with WhatsApp and
Outlook. To hand ownership to brew: `brew install --cask --adopt <name>`.
Manually installed fonts are worse: a version mismatch can leave brew having
deleted some faces before it aborts. Neither affects a genuinely fresh machine.

**`~/Scripts` is the `alt-x` menu.** The launcher lists that directory and runs
what you pick, exactly as the i3 version does on Arch, so anything symlinked in
there becomes a menu entry and nothing else needs editing. `install.sh` decides
what goes in; the launcher itself lives in `~/.local/bin` so it does not list
itself. Support files can sit alongside as dotfiles, which `ls` skips.

**Deliberately not tracked:** qbittorrent (`install.sh` still de-quarantines it
if installed by hand, since its cask is ad-hoc signed), Discord, and
Progress-tracker.

## Layout

| Path | What |
|---|---|
| `Brewfile` | every package, grouped and commented |
| `install.sh` | the whole bootstrap; idempotent |
| `drag-mac/` | macOS drag source for ranger's `dn`; see its `PLAN.md` |
| `githooks/` | tracked hooks, symlinked into `.git/hooks` by install.sh |
| `karabiner/` | keyboard remaps; edit `spec.json`, see its `README.md` |
| `macos/defaults.sh` | `defaults write` settings, which cannot be symlinked |
| `scripts/` | helpers the configs invoke |
| `secrets.gpg` | encrypted; see `scripts/secrets.sh` |
