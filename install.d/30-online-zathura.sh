#!/usr/bin/env bash
#
# One job: online-zathura (reading-state sync).
#
# Its own repo, built with its Makefile into ~/.local/bin. Needs go.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "online-zathura (reading-state sync)"

# Reading-state sync used by scripts/library. It's its own repo, built with
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
