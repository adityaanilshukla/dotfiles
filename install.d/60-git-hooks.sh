#!/usr/bin/env bash
#
# One job: git hooks.
#
# Hooks live in .git/hooks, which git does not track, so they never clone.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "git hooks"

# Hooks live in .git/hooks, which git does not track, so they never arrive with
# a clone. The real script is a tracked file and gets symlinked into place here
# instead; editing githooks/ then updates the live hook immediately.
#
# post-checkout warns when the checked-out branch is not the one whose config
# this machine runs. The two dirs above are symlinks into the repo, so the
# checked-out branch IS the live ranger and aerospace config.
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  mkdir -p "$DOTFILES_DIR/.git/hooks"
  for hook in "$DOTFILES_DIR"/githooks/*; do
    [[ -f "$hook" ]] || continue
    ln -sf "$hook" "$DOTFILES_DIR/.git/hooks/$(basename "$hook")"
    echo "Linked $hook -> .git/hooks/$(basename "$hook")"
  done
fi
