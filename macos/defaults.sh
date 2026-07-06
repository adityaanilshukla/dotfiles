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

echo "Applied macOS defaults. Restart affected apps (e.g. VS Code) to pick them up."
