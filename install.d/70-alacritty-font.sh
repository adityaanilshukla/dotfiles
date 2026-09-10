#!/usr/bin/env bash
#
# One job: alacritty font size for this display.
#
# alacritty.toml sets no size; it imports one this generates.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "alacritty font size for this display"

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
