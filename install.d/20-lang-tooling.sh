#!/usr/bin/env bash
#
# One job: language tooling (rust, pipx, npm).
#
# Tools installed by their own ecosystem package manager, which a Brewfile
# entry cannot cover and which would otherwise silently not exist.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Language tooling (rust, pipx, npm)"

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
