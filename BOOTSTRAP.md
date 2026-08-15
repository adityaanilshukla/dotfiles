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
- **drag-mac** — builds the PyObjC venv behind ranger's `dn` binding, then
  self-tests it. Self-healing: a Homebrew python upgrade breaks a venv, so it
  checks whether the venv can actually import its frameworks, not merely
  whether the directory exists.
- **Symlinks** every tracked config into place, and the git hooks.
- **Starts** the sketchybar and syncthing services.
- **VS Code extensions** and the macOS `defaults`.

## Manual steps afterwards

`install.sh` prints these too. Nothing can automate them.

| Step | Why |
|---|---|
| Open AeroSpace once | Installing a cask does not launch it, and `start-at-login` only registers after a first run. This also raises the Accessibility prompt. |
| Grant **Accessibility** to AeroSpace, Karabiner, BetterDisplay, Raycast | AeroSpace cannot tile without it, and `ctrl-shift-x` (dismiss notifications) needs it. |
| Approve the **macfuse** kernel extension, then reboot | Kernel extensions require explicit approval. |
| `gh auth login` | per-device auth |
| `tailscale up` | per-device auth; links this machine to `brovo` |
| `make -C ~/Projects/online-zathura join` | mints this device's Turso token for reading-state sync |
| Import your **GPG key**, then `scripts/secrets.sh decrypt` | The private key is deliberately not in this repo. Without it `secrets.gpg` cannot be opened. |

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
| `macos/defaults.sh` | `defaults write` settings, which cannot be symlinked |
| `scripts/` | helpers the configs invoke |
| `secrets.gpg` | encrypted; see `scripts/secrets.sh` |
