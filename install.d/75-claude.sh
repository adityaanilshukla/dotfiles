#!/usr/bin/env bash
#
# One job: claude code hooks.
#
# Registers the hooks in settings.json. Needs 55-symlinks to have run.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Claude Code hooks"

# Registers the notification hooks in ~/.claude/settings.json. Must run after
# the symlink loops above: the module checks that notify.sh is actually in
# place and bails rather than registering a hook that would fail on every
# event. Non-fatal like karabiner — a missing desktop notification must not
# abort a machine setup, and this script runs under `set -e`.
if [[ -x "$DOTFILES_DIR/claude/install.sh" ]]; then
  echo "Configuring Claude Code hooks..."
  "$DOTFILES_DIR/claude/install.sh" \
    || echo "  claude module failed — re-run '$DOTFILES_DIR/claude/install.sh'."
fi
