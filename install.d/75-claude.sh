#!/usr/bin/env bash
#
# One job: claude code settings, for every profile this machine uses.
#
# Registers the notification hooks, the sudo guard and the renderer pin in each
# profile's settings.json. Needs 55-symlinks to have run.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Claude Code settings"

# Must run after the symlink loops: claude/install.sh checks that notify.sh is
# actually in place and bails rather than registering a hook that would fail on
# every event. Non-fatal like karabiner — a missing desktop notification must
# not abort a machine setup, and this script runs under `set -e`.
if [[ ! -x "$DOTFILES_DIR/claude/install.sh" ]]; then
  warn "claude/install.sh missing or not executable — settings not registered."
  exit 0
fi

# ~/.claude is unconditional: it is the stock profile and the one anything
# outside the zsh functions gets — a script, an IDE extension, a cron job.
PROFILES=("$HOME/.claude")

# A second account is opt-in per machine, because the machines genuinely
# disagree: molly has a work login, the personal one has no use for it.
#
# WHY THE PROFILE IS CONFIGURED HERE AND NOT ON FIRST USE. A profile with no
# `tui` key does not get a default renderer, it gets a remote rollout gate that
# can hand it the fullscreen one — and fullscreen takes the alternate screen,
# where nothing reaches tmux scrollback. That is what made the second account
# unusable in tmux while a plain `claude` was fine: the stock profile had the
# key pinned and the new one never had. claude/install.sh carries the detail.
# Creating the profile here, before anything launches into it, is what keeps
# that from happening again on the next machine.
if feature_on claude_work_profile; then
  PROFILES+=("$HOME/.claude-work")
else
  info "work profile not enabled for $DOTFILES_MACHINE (machines/${DOTFILES_MACHINE}.conf)"
  # Deliberately no undo path, unlike the mouse jiggler. The only thing to
  # remove would be a directory holding a working login, and deleting that to
  # tidy up is the worse mistake — 31eb550 left it on disk for the same reason.
  # Flipping the flag off stops this maintaining the profile; it does not
  # revoke it. `rm -rf ~/.claude-work` is a human's call, not an installer's.
fi

for profile in "${PROFILES[@]}"; do
  info "configuring ${profile/#$HOME/~}..."
  "$DOTFILES_DIR/claude/install.sh" "$profile" \
    || warn "claude module failed for $profile — re-run '$DOTFILES_DIR/claude/install.sh $profile'."
done
