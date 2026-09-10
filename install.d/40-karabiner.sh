#!/usr/bin/env bash
#
# One job: karabiner keyboard remaps.
#
# Delegates to karabiner/install.sh, which owns the generated rules.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Karabiner keyboard remaps"

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
