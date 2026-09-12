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

  # The work profile, if this machine has one. Settings are per-profile, so the
  # sudo guard and the notification hooks have to be registered there too --
  # otherwise the only account without the guard is the work one.
  #
  # Conditional on the directory rather than created here: ~/.claude-work
  # existing is what marks a machine as opted in to the second account, and
  # scripts/claude-profile reads the same signal to decide whether to prompt at
  # all. Creating it unasked would mean every machine prompting for a profile it
  # has never logged into. BOOTSTRAP.md has the one-time setup.
  if [[ -d "$HOME/.claude-work" ]]; then
    "$DOTFILES_DIR/claude/install.sh" "$HOME/.claude-work" \
      || echo "  claude work profile failed — re-run with ~/.claude-work."
  fi
fi
