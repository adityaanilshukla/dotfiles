#!/usr/bin/env bash
set -euo pipefail

FONT_NAME="HackNerdFont-Regular.ttf"
FONT_DIR="$HOME/Library/Fonts"
FONT_URL="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf"
TARGET="$FONT_DIR/$FONT_NAME"

echo "Installing Hack Nerd Font (Regular)..."
mkdir -p "$FONT_DIR"

if [[ -f "$TARGET" ]]; then
  echo "Font already exists at: $TARGET"
else
  echo "Downloading font..."
  curl -L --fail "$FONT_URL" -o "$TARGET"
  echo "Saved to: $TARGET"
fi

# macOS version check (major)
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"

echo "Refreshing font availability..."
if [[ "$MACOS_MAJOR" -ge 14 ]]; then
  # ATSUTIL is deprecated on macOS 14+. Best effort: restart font services.
  # These may or may not be running depending on the system state.
  pkill -x fontd 2>/dev/null || true
  pkill -x FontRegistryAgent 2>/dev/null || true
  # Finder restart can help some apps notice changes
  killall Finder 2>/dev/null || true
  echo "macOS $MACOS_MAJOR detected: skipped atsutil (deprecated)."
else
  # Older macOS: atsutil is still useful
  atsutil server -shutdown || true
  atsutil databases -removeUser || true
  atsutil server -ping || true
fi

echo "Done! If it doesn't show up immediately, restart the app using fonts (Terminal/VS Code), or log out/in."
