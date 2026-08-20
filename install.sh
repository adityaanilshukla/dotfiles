#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

# --- Homebrew + packages --------------------------------------------------
# Install Homebrew if missing, then install every app/tool from the Brewfile.
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for the rest of this script (Apple Silicon vs Intel).
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
  echo "Installing packages from Brewfile..."
  # Don't abort the whole setup if a single cask needs a password/retry.
  brew bundle --file="$DOTFILES_DIR/Brewfile" \
    || echo "brew bundle finished with some failures — review the output above."
fi

# --- De-quarantine ad-hoc-signed casks ------------------------------------
# qBittorrent's cask build is ad-hoc signed (not notarized), so Gatekeeper
# quarantines it and blocks first launch. Strip the quarantine flag so it opens
# without the "could not verify" prompt. Re-runs harmlessly if already clear.
for app in "/Applications/qBittorrent.app"; do
  [[ -d "$app" ]] && xattr -dr com.apple.quarantine "$app" 2>/dev/null || true
done

# --- Tooling that does not come from brew ---------------------------------
# Each of these is installed by its own ecosystem's package manager, so a
# Brewfile entry cannot cover them and they would silently not exist.

# Rust via rustup, not brew: rustup owns toolchain updates and component
# installs (rust-analyzer, clippy, rustfmt), which a brew formula cannot do.
if ! command -v cargo >/dev/null 2>&1; then
  echo "Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path \
    || echo "  rustup install failed — see https://rustup.rs"
fi

# pipx: isolated CLI apps. nbstripout strips notebook output before commits;
# otpfetch is the 2FA helper.
if command -v pipx >/dev/null 2>&1; then
  for app in nbstripout otpfetch; do
    if ! pipx list --short 2>/dev/null | grep -q "^$app "; then
      echo "Installing $app via pipx..."
      pipx install "$app" >/dev/null || echo "  pipx install $app failed"
    fi
  done
fi

# eslint_d is what the nvim JS/TS linting talks to; without it that setup is
# configured and inert.
if command -v npm >/dev/null 2>&1; then
  if ! npm ls -g --depth=0 2>/dev/null | grep -q "eslint_d@"; then
    echo "Installing eslint_d..."
    npm install -g eslint_d >/dev/null 2>&1 || echo "  npm install -g eslint_d failed"
  fi
fi

# --- Neovim (via bob) -----------------------------------------------------
# nvim is not a brew formula here. bob manages the version and drops the binary
# in ~/.local/share/bob/nvim-bin, which zshrc puts on PATH. Installing bob alone
# leaves that empty, so without this a fresh machine has every nvim config file
# and no nvim.
if command -v bob >/dev/null 2>&1; then
  if [[ ! -x "$HOME/.local/share/bob/nvim-bin/nvim" ]]; then
    echo "Installing Neovim via bob..."
    bob use "${BOB_NVIM_VERSION:-nightly}" \
      || echo "  bob failed — install manually: bob use nightly"
  fi
fi

# The config is its own repo, not part of this one, so bob alone gives you a
# working nvim binary and a completely empty config. Nothing errors; nvim just
# opens bare, which is the least obvious way for 114 files to go missing.
# Needs the SSH key to be on GitHub already.
NVIM_CONFIG_DIR="$HOME/.config/nvim"
if [[ ! -d "$NVIM_CONFIG_DIR" ]]; then
  echo "Cloning Neovim config..."
  git clone git@github.com:adityaanilshukla/nvim.git "$NVIM_CONFIG_DIR" \
    || echo "  couldn't clone nvim config (check SSH access) — nvim will start with no config."
fi

# --- online-zathura -------------------------------------------------------
# Reading-state sync used by scripts/readbook. It's its own repo, built with
# its Makefile into ~/.local/bin. Needs `go` (Brewfile). Actual Turso sync also
# needs a one-time `make join` per machine to mint this device's token — that
# step is manual because it writes credentials.
OZ_DIR="$HOME/Projects/online-zathura"
if [[ ! -x "$HOME/.local/bin/online-zathura" ]]; then
  if [[ ! -d "$OZ_DIR" ]]; then
    echo "Cloning online-zathura..."
    git clone git@github.com:adityaanilshukla/online-zathura.git "$OZ_DIR" \
      || echo "Couldn't clone online-zathura (check SSH access) — skipping."
  fi
  if [[ -d "$OZ_DIR" ]] && command -v go >/dev/null 2>&1; then
    echo "Building online-zathura..."
    make -C "$OZ_DIR" install \
      || echo "online-zathura build failed — build it manually: make -C '$OZ_DIR' install"
  fi
fi

# --- drag-mac -------------------------------------------------------------
# PyObjC drag source behind ranger's dn binding. Homebrew's python3 is PEP 668
# externally managed, so pip refuses to install into it and PyObjC has to live
# in a venv. Idempotent: re-running only upgrades what's already there.
DRAG_MAC_VENV="$HOME/.local/share/drag-mac/venv"
if [[ "$(uname -s)" == "Darwin" ]]; then
  # Test what the venv can actually do, not whether its directory exists. A venv
  # keeps working only as long as the python it was built against stays put, so
  # a Homebrew python upgrade silently breaks it. Importing the frameworks the
  # tool really uses is the only check that catches that, and it makes this
  # block self-healing on every run.
  if ! "$DRAG_MAC_VENV/bin/python3" -c "import objc, AppKit, Quartz" >/dev/null 2>&1; then
    echo "Building drag-mac venv..."
    # :? so an unset or empty variable aborts instead of expanding to something
    # catastrophic.
    rm -rf "${DRAG_MAC_VENV:?refusing to remove an empty path}"
    # Delegated to the Makefile on purpose: it already owns the dependency list,
    # and duplicating it here is how the two drift. They did, briefly, and
    # `make test` then failed on a fresh machine for want of pytest.
    if make -C "$DOTFILES_DIR/drag-mac" venv >/dev/null; then
      echo "  drag-mac venv built"
    else
      echo "  drag-mac venv FAILED — dn will report it. Retry: make -C '$DOTFILES_DIR/drag-mac' venv"
    fi
  fi

  # Prove it end to end rather than assuming, so a broken install is loud here
  # instead of showing up later as dn appearing to do nothing.
  if "$DRAG_MAC_VENV/bin/python3" "$DOTFILES_DIR/drag-mac/drag_mac.py" >/dev/null 2>&1; then
    echo "  drag-mac self-test unexpectedly passed with no arguments"
  elif [[ $? -eq 2 ]]; then
    echo "  drag-mac ready"
  else
    echo "  drag-mac self-test FAILED — check 'make -C $DOTFILES_DIR/drag-mac test'"
  fi
fi

# --- Karabiner ------------------------------------------------------------
# Keyboard remaps. Its own module because karabiner.json cannot be symlinked:
# the settings GUI rewrites it, and the installer merges generated rules into
# it. Needs brew (karabiner-elements, jq), so it has to run after the Brewfile.
#
# Non-fatal on purpose. A keyboard remapper failing — usually ungranted
# permissions on a fresh machine — must not abort a whole machine setup, and
# this script runs under `set -e`.
if [[ -x "$DOTFILES_DIR/karabiner/install.sh" ]]; then
  echo "Configuring Karabiner..."
  "$DOTFILES_DIR/karabiner/install.sh" \
    || echo "  karabiner module failed — re-run '$DOTFILES_DIR/karabiner/install.sh' after granting permissions."
fi

# --- Symlinks -------------------------------------------------------------
# Single-file configs.
files=(
  "zsh/zshrc:$HOME/.zshrc"
  "tmux/tmux.conf:$HOME/.tmux.conf"
  "git/gitconfig:$HOME/.gitconfig"
  "alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
  "zathura/zathurarc:$HOME/.config/zathura/zathurarc"

  # Karabiner is deliberately absent here: karabiner.json is generated and
  # merged by karabiner/install.sh, not symlinked. See karabiner/README.md.

  # ~/Scripts is the alt-x launcher's menu: whatever is linked in here is what
  # it offers. Keep that in mind before adding to it.
  "scripts/readbook:$HOME/Scripts/readbook"

  # Night Shift toggle, a thin wrapper over the Raycast extension so the
  # launcher has a file to list. Needs devmoath/night-light installed.
  "scripts/nightlight:$HOME/Scripts/nightlight"

  # sketchybar-backed countdown timer — see sketchybar/plugins/timer.sh
  "scripts/t:$HOME/.local/bin/t"

  # zathura, privately: open any document with no reading state stored and
  # nothing synced to Turso. Also what readbook's ctrl-o hands off to.
  "scripts/zp:$HOME/.local/bin/zp"

  # notification dismisser, run by aerospace's alt-shift-x binding
  "scripts/dismiss-notifications:$HOME/Scripts/dismiss-notifications"

  # the alt-x launcher itself. Deliberately NOT in ~/Scripts, or it would list
  # itself in its own menu.
  "scripts/launcher:$HOME/.local/bin/launcher"

  # macOS drag source — ranger's dn binding runs this, since dragon-drop is
  # X11-only. Needs the venv built below.
  "scripts/drag-mac:$HOME/.local/bin/drag-mac"

  # alacritty font size per screen. Run by sketchybar's display_change event
  # (sketchybar/plugins/alacritty-font.sh) and by hand after changing the two
  # sizes inside it. Reads scripts/display-info.swift from beside itself, which
  # is why the link target keeps the same basename.
  "scripts/alacritty-font-size:$HOME/.local/bin/alacritty-font-size"

  # VS Code (macOS config path)
  "vscode/settings.json:$HOME/Library/Application Support/Code/User/settings.json"
  "vscode/keybindings.json:$HOME/Library/Application Support/Code/User/keybindings.json"
)

# Whole-directory symlinks — for multi-file configs. Linked as a single dir so
# new files inside are tracked automatically without touching this list. Only
# use for configs that DON'T write runtime state into their config dir.
dirs=(
  "sketchybar:$HOME/.config/sketchybar"
  "aerospace:$HOME/.config/aerospace"
  "ranger:$HOME/.config/ranger"
)

# --- alacritty font size --------------------------------------------------
# alacritty.toml deliberately sets no font size; it imports one from
# ~/.config/alacritty/font-size.toml, which this script generates to suit
# whichever screen is attached. Generate it now, because until it exists
# alacritty falls back to its own default of 11.25, which is unreadably small
# on both screens here. sketchybar regenerates it on every display change.
if [[ -x "$DOTFILES_DIR/scripts/alacritty-font-size" ]]; then
  echo "Setting alacritty font size for the current display..."
  "$DOTFILES_DIR/scripts/alacritty-font-size" \
    || echo "  couldn't set the alacritty font size — run alacritty-font-size by hand."
fi

# --- git hooks ------------------------------------------------------------
# Hooks live in .git/hooks, which git does not track, so they never arrive with
# a clone. The real script is a tracked file and gets symlinked into place here
# instead; editing githooks/ then updates the live hook immediately.
#
# post-checkout warns when the checked-out branch is not the one whose config
# this machine runs. The two dirs above are symlinks into the repo, so the
# checked-out branch IS the live ranger and aerospace config.
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  mkdir -p "$DOTFILES_DIR/.git/hooks"
  for hook in "$DOTFILES_DIR"/githooks/*; do
    [[ -f "$hook" ]] || continue
    ln -sf "$hook" "$DOTFILES_DIR/.git/hooks/$(basename "$hook")"
    echo "Linked $hook -> .git/hooks/$(basename "$hook")"
  done
fi

for pair in "${files[@]}"; do
  src="${pair%%:*}"
  dest="${pair#*:}"
  src_path="$DOTFILES_DIR/$src"

  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mv "$dest" "$dest.backup"
    echo "Backed up $dest to $dest.backup"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -sf "$src_path" "$dest"
  echo "Linked $src_path -> $dest"
done

for pair in "${dirs[@]}"; do
  src="${pair%%:*}"
  dest="${pair#*:}"
  src_path="$DOTFILES_DIR/$src"

  # Back up a real directory; a stale symlink is just replaced.
  if [[ -d "$dest" && ! -L "$dest" ]]; then
    mv "$dest" "$dest.backup"
    echo "Backed up $dest to $dest.backup"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src_path" "$dest"
  echo "Linked $src_path -> $dest"
done

# --- Services -------------------------------------------------------------
# Installing sketchybar and symlinking its config is not enough: it runs as a
# launch agent, so without this a fresh machine has the bar fully configured
# and simply no bar on screen. Starting an already-started service is harmless,
# so this stays idempotent.
for svc in sketchybar syncthing; do
  command -v "$svc" >/dev/null 2>&1 || continue
  if ! brew services list 2>/dev/null | grep -qE "^$svc\s+started"; then
    echo "Starting $svc service..."
    brew services start "$svc" >/dev/null \
      || echo "  couldn't start $svc — run 'brew services start $svc'"
  fi
done

# --- VS Code extensions ---------------------------------------------------
# Resolve the `code` CLI even if it isn't on PATH yet (fresh install).
CODE_BIN="$(command -v code || true)"
if [[ -z "$CODE_BIN" ]]; then
  app_cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  [[ -x "$app_cli" ]] && CODE_BIN="$app_cli"
fi

ext_list="$DOTFILES_DIR/vscode/extensions.txt"
if [[ -z "$CODE_BIN" ]]; then
  echo "VS Code 'code' CLI not found — install VS Code, then re-run this script to add extensions."
elif [[ -f "$ext_list" ]]; then
  echo "Installing VS Code extensions..."
  while IFS= read -r ext; do
    ext="${ext%%#*}"                       # strip inline comments
    ext="$(echo "$ext" | tr -d '[:space:]')"  # trim whitespace
    [[ -z "$ext" ]] && continue
    "$CODE_BIN" --install-extension "$ext" --force
  done < "$ext_list"
fi

# --- macOS defaults -------------------------------------------------------
# `defaults` settings can't be symlinked (cfprefsd owns the plists), so re-apply
# them from a script.
if [[ -x "$DOTFILES_DIR/macos/defaults.sh" ]]; then
  echo "Applying macOS defaults..."
  "$DOTFILES_DIR/macos/defaults.sh"
fi

echo "Done. Remaining manual steps:"
echo "  - Open AeroSpace once. Installing the cask does not launch it, and the"
echo "    start-at-login setting in aerospace.toml only registers after a first"
echo "    launch. Opening it is also what raises the Accessibility prompt."
echo "  - Grant permissions to AeroSpace, Karabiner-Elements, BetterDisplay and"
echo "    Raycast in System Settings > Privacy & Security. AeroSpace needs it to"
echo "    tile at all, and alt-shift-x (dismiss notifications) needs it too."
echo "  - macfuse needs a kernel extension approved in System Settings, then a"
echo "    reboot."
echo "  - For zathura reading-state sync, run 'make -C $HOME/Projects/online-zathura join'"
echo "    once on this machine to mint its Turso token."
echo "  - Install the Raycast extension 'Set Audio Device' (benvp/audio-device)."
echo "    aerospace's alt-ctrl-z and the sketchybar audio glyph both deeplink"
echo "    straight into it, and both do nothing until it is installed:"
echo "      open 'raycast://extensions/benvp/audio-device'"
echo "  - Install the Raycast extension 'Night Light' (devmoath/night-light)."
echo "    The alt-x launcher's nightlight entry is a wrapper around it, and"
echo "    does nothing at all until it is installed:"
echo "      open 'raycast://extensions/devmoath/night-light'"
echo "  - Import $DOTFILES_DIR/vimium_c-*.json into Vimium C (Options > Backup"
echo "    and restore). The extension keeps its settings in browser storage, so"
echo "    the file in this repo is a backup, not a live config."
echo "  - Browser-side keyboard config lives in the browser profile, not on disk:"
echo "    set Dark Reader to Alt+Shift+D in about:addons > Manage Extension"
echo "    Shortcuts, and paste the userscripts from ~/Projects/tampermonkey into"
echo "    Tampermonkey. The Glove80 Alt chords in karabiner/spec.json drive both."
