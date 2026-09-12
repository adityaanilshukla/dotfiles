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
- **Claude Code hooks** — registers `claude/hooks/notify.sh` in
  `~/.claude/settings.json`, which posts a desktop banner and plays a sound
  when a session finishes or needs input. Merged rather than symlinked, for the
  same reason as `karabiner.json`: Claude Code writes to that file itself. The
  merge replaces its own entries instead of appending, because appending is how
  the machine this came from ended up firing two banners and two sounds per
  event. The same step registers `claude/hooks/no-sudo.sh`, a PreToolUse guard
  that refuses `sudo`, `doas`, and osascript's `with administrator privileges`
  from inside a session, so an escalation has to be typed by a human in a
  terminal. Matching deny rules go in alongside it: a permission rule only
  matches the start of a command, so it catches a leading `sudo` and not
  `x; sudo y` or the osascript route.

  It is a guardrail against habit, not a sandbox — anything that hides the word
  (base64, a variable, a script that escalates internally) goes straight
  through. It also false-positives on writing *about* sudo: a chained example
  inside an `echo` or a heredoc trips it, because the guard reads the command
  text and cannot tell quoting from execution. Rephrase, or assemble the string
  from fragments.
- **Starts** the sketchybar and syncthing services. Tailscale is reported on, not
  started: its daemon runs as root and joining the tailnet is a browser login.
- **VS Code extensions** and the macOS `defaults`.

## Manual steps afterwards

`install.sh` prints these too. Nothing can automate them.

| Step | Why |
|---|---|
| Grant **Accessibility** to AeroSpace, Karabiner, BetterDisplay, Raycast, sketchybar (install.sh launches AeroSpace, so the prompt is already waiting) | AeroSpace cannot tile without it, and `alt-shift-x` (dismiss notifications) needs it. sketchybar needs it only for the unread counter, and only for Catalyst apps like WhatsApp, whose Dock badge has to be read off the Dock itself; without the grant that app shows `?` instead of a number. |
| Approve the **Karabiner driver extension** and its Input Monitoring, then reboot | Nothing remaps until the DriverKit extension is `activated enabled`. `karabiner/install.sh` prints the exact panes; `karabiner/verify.sh` confirms. |
| `gh auth login` | per-device auth |
| `claude` then `/login` | per-device auth, personal account. Both Claude accounts are per-device and neither is in this repo. |
| **Second Claude account (optional):** `mkdir -p ~/.claude-work && ~/dotfiles/claude/install.sh ~/.claude-work`, then `CLAUDE_PROFILE=work claude` and `/login` | Sets up the work account beside the personal one. The two coexist because Claude Code names its Keychain entry after `CLAUDE_CONFIG_DIR`, so both tokens are stored at once and neither logs the other out — after this one-time login, switching costs nothing. Creating `~/.claude-work` is also the switch that turns the profile prompt on: the `claude` wrapper in `zsh/zshrc` stays silent on a machine without it. `install.sh` re-registers the hooks and sudo deny rules in both profiles from then on. See `scripts/claude-profile`. |
| `sudo brew services start tailscale` then `sudo tailscale up --operator=$USER` | per-device auth; links this machine to `brovo`. Two commands, not one: the daemon needs root for a utun interface and for MagicDNS, so it is a LaunchDaemon and `brew services` alone will not start it. `--operator` is what makes plain `tailscale status` work without sudo afterwards. Until this is done the host aliases in `ssh/config` resolve to nothing. |
| `sudo systemsetup -setremotelogin on` | turns on sshd, so `brovo` can copy files *from* this Mac. Needs Full Disk Access for the terminal on recent macOS; if it refuses, grant that in System Settings > Privacy & Security first. |
| `make -C ~/Projects/online-zathura join` | mints this device's Turso token for reading-state sync |
| `scripts/build-zathura-gtk4` | Builds zathura 2026.07.18 (GTK4) into `~/.local/zathura-gtk4`. The Homebrew tap is stuck on the last GTK3 release, whose macOS backend re-uploads the whole viewport every frame — fullscreen on a Retina display jitters while scrolling. Optional: `zsh/zshrc`, `scripts/zp` and `scripts/library` all fall back to the brew build when this has not been run. Compiles from source and pulls in gtk4, which is why it is not in `install.sh`. |
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

**Deleting something from this repo does not delete it from your machines.**
Symlinks go stale, `defaults` keys stay written, login items stay registered and
LaunchAgents stay loaded. A commit that removes a feature removes it from a
*fresh* install and from nowhere else, so the repo reads as correct while the
machines quietly disagree.

That is not hypothetical: `78e69bc` retired the start-comms LaunchAgent and
deleted its plist, its script and the install.sh block that placed it — and the
Mac that had been set up before that commit went on launching the comms apps at
login for another five days. Nothing was wrong with the commit except what it
did not do.

So retiring something that install.sh *placed* means naming it for removal, not
just deleting the source. `install.sh` has a `retired_agents` list for exactly
this; the entries stay indefinitely, since the loop skips anything already gone.
The same care is owed to symlinks and login items, which have no such list yet.

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

**If epubs stop opening in zathura but PDFs still do, the plugins need a
rebuild.** They come from a tap with no bottles, so brew compiles them against
whatever mupdf/poppler is installed that day and never rebuilds them when those
upgrade. mupdf refuses to open anything once its header and library versions
disagree, and it is the plugin that handles epub/mobi/fb2, so the breakage looks
format-specific rather than version-specific. `library` and `zp` now detect this
themselves and print the reason plus a plugin check, rather than leaving an
empty zathura window with no explanation — zathura does not exit when it cannot
read a document, so their stderr goes to `~/.cache/library/last-launch.log`
instead of `/dev/null`. `check-zathura-plugins` names the drift on demand; the
fix is one command:

```sh
brew reinstall --build-from-source zathura-pdf-mupdf zathura-pdf-poppler
```

**Deliberately not tracked:** qbittorrent (`install.sh` still de-quarantines it
if installed by hand, since its cask is ad-hoc signed), Discord, and
Progress-tracker.

## Per-machine ssh hosts

`ssh/config` is shared by every machine, so anything true of only one of them —
a literal address, a non-standard port, a per-device key, a work jump box —
goes in `~/.ssh/config.local` instead. That file is not in this repo and
nothing here creates or touches it.

The `Include` sits at the very top of `ssh/config` on purpose: ssh takes the
first value it sees for a keyword, so an Include lower down could never
override the blocks above it. Missing file is a no-op, so a fresh machine needs
nothing. `git pull && ./install.sh` cannot clobber it, because `config.local`
is not in the symlink list — which is the reason for splitting it out at all.

## Leaving it running with the lid shut

`awake on 3h` (from `scripts/awake`) keeps this Mac up with the lid closed, so
it can sit locked in a bag on a phone hotspot and still answer `claude
--remote-control`. `awake off` ends it early, `awake status` reports what is
holding on, `awake lock` locks the screen without sleeping.

Three things are easy to get wrong here:

- **`caffeinate` does not survive a closed lid.** None of its assertions apply
  to the clamshell path. Claude Code runs `caffeinate -i -t 300` for the life of
  a session, which is idle-sleep only — a running caffeinate is not evidence the
  machine will stay up once the lid is down. `pmset disablesleep 1` is the only
  switch that works, and it needs root.
- **`disablesleep` persists, including across a reboot.** That is why `awake on`
  takes a duration and arms a root-owned timer to clear the flag. Never set the
  flag by hand; a laptop that never sleeps in a closed bag overheats and runs
  the battery flat. If `awake status` reports `NO WATCHDOG`, run `awake off`.
- **Idle sleep is a separate door, and `awake` does not cover it.** A lid left
  open still sleeps. Once the display stops counting as on, `powerd` drops the
  assertion named `Prevent sleep while display is on`, and `sleep 1` — one
  minute, the stock value — takes the machine down. On a laptop running long
  sessions that is the usual way one dies: over four days here, one Mac logged
  28 idle sleeps against 12 from the lid, and in six of them the last
  `caffeinate` had dropped five to eight seconds earlier.

  **The switch is the screen saver, not power management.** System Settings >
  Lock Screen > "Start Screen Saver when inactive" > Never. `macos/defaults.sh`
  now sets it (`defaults -currentHost write com.apple.screensaver idleTime 0`);
  it needs a logout to take effect. Measured: the Mac with this set to Never
  logged **zero** idle sleeps in seven days of `pmset -g log`; the one on the
  default logged 28 in four and a half.

  Do not go looking for this in `pmset`. It is not there — the setting lives in
  a per-host preferences plist, so two machines can have byte-identical
  `pmset -g custom` output and behave completely differently. That mistake cost
  an evening here.

  `pmset -c sleep 0` as root also works, and switches off idle sleep on the
  adapter only. It is a second line of defence rather than the fix — worth
  having if you want the guarantee to survive an OS update resetting the screen
  saver, not worth a password prompt in `install.sh` otherwise.

Remote Control is an outbound connection to Anthropic, so it needs the machine
awake and *some* working route — it does not need Tailscale, and it does not
need `sshd`. Tailscale only matters for `ssh`/`scp` between hosts.

## Layout

| Path | What |
|---|---|
| `Brewfile` | every package, grouped and commented |
| `install.sh` | the whole bootstrap; idempotent |
| `drag-mac/` | macOS drag source for ranger's `dn`; see its `PLAN.md` |
| `githooks/` | tracked hooks, symlinked into `.git/hooks` by install.sh |
| `karabiner/` | keyboard remaps; edit `spec.json`, see its `README.md` |
| `macos/defaults.sh` | `defaults write` settings, which cannot be symlinked |
| `scripts/awake` | keep the Mac up with the lid shut; see above |
| `scripts/` | helpers the configs invoke |
| `secrets.gpg` | encrypted; see `scripts/secrets.sh` |
