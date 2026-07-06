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

# --- Symlinks -------------------------------------------------------------
# Single-file configs.
files=(
  "zsh/zshrc:$HOME/.zshrc"
  "tmux/tmux.conf:$HOME/.tmux.conf"
  "git/gitconfig:$HOME/.gitconfig"
  "alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
  "zathura/zathurarc:$HOME/.config/zathura/zathurarc"

  # Karabiner writes runtime state (log/pid/tmp) into ~/.config/karabiner, so
  # only the config file is symlinked — the directory itself stays real.
  "karabiner/karabiner.json:$HOME/.config/karabiner/karabiner.json"

  # zathura launcher — aerospace's alt-x binding runs ~/Scripts/readbook.
  "scripts/readbook:$HOME/Scripts/readbook"

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
echo "  - Grant permissions to AeroSpace, Karabiner-Elements, BetterDisplay and"
echo "    Raycast in System Settings > Privacy & Security."
echo "  - For zathura reading-state sync, run 'make -C $HOME/Projects/online-zathura join'"
echo "    once on this machine to mint its Turso token."
