#!/usr/bin/env bash
#
# One job: macos defaults.
#
# `defaults` settings cannot be symlinked, so re-apply them from a script.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "macOS defaults"

# `defaults` settings can't be symlinked (cfprefsd owns the plists), so re-apply
# them from a script.
if [[ -x "$DOTFILES_DIR/macos/defaults.sh" ]]; then
  echo "Applying macOS defaults..."
  "$DOTFILES_DIR/macos/defaults.sh"
fi
