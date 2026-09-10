#!/usr/bin/env bash
#
# One job: neovim (bob) + its config repo.
#
# The nvim binary via bob, and the config, which is its own repo. Either one
# missing leaves you with a working editor and no setup, or vice versa.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Neovim (bob) + its config repo"

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
