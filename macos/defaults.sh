#!/usr/bin/env bash
# macOS `defaults` settings.
#
# These live in cfprefsd's preferences database (~/Library/Preferences/*.plist),
# which the daemon caches and rewrites on its own — so they can't be symlinked
# like a normal dotfile. Instead we re-apply the `defaults write` commands on a
# new machine. install.sh runs this script.
set -euo pipefail

# VS Code: disable the press-and-hold accent popup so a held key repeats
# instead. Needed for Vim-style navigation (holding h/j/k/l) in VSCodeVim.
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

# Alacritty: turn off Core Text's stroke thickening. With no value set macOS
# applies full smoothing, which fattens every glyph and reads as blurry on a
# non-Retina external display. Measured on the Dell at font size 20: unset and
# 3 are indistinguishable (~8500 lit pixels), 0 drops to ~6950, i.e. 19% fewer
# lit pixels and visibly thinner strokes.
#
# Scoped to org.alacritty on purpose, so it doesn't restyle the rest of the OS.
# Alacritty reads it once at process start, so a new window is not enough: quit
# with Cmd-Q and relaunch.
defaults write org.alacritty AppleFontSmoothing -int 0

echo "Applied macOS defaults. Restart affected apps to pick them up:"
echo "  - VS Code (press-and-hold)"
echo "  - Alacritty, full Cmd-Q and relaunch (font smoothing)"
