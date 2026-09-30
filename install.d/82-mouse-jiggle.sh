#!/usr/bin/env bash
#
# One job: the mouse jiggler, on the machines that want it.
#
# Nudges the cursor a pixel and back every two minutes so this Mac reads as
# present rather than idle. See scripts/mouse-jiggle for why that is a cursor
# move and not caffeinate.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Mouse jiggler"

# Opt-in per machine, because the two machines genuinely disagree: the work
# laptop's presence is being reported to someone, the personal one's is not.
# machines/<hostname>.conf is where that is written down.
#
# This step has to run in BOTH directions. Flipping the flag off and deleting
# nothing leaves the agent loaded and jiggling on the machine that already had
# it, which is precisely the failure 90-retired-agents.sh exists to document:
# the repo says one thing and the machine does another for weeks. So the off
# path actively unloads rather than merely declining to install.
#
# 90-retired-agents.sh stays the mechanism for retiring the feature outright,
# for machines that have no config file naming it either way.
JIGGLE_LABEL="com.aditya.dotfiles.mouse-jiggle"
JIGGLE_PLIST="$HOME/Library/LaunchAgents/${JIGGLE_LABEL}.plist"

jiggle_loaded() { launchctl print "gui/$(id -u)/${JIGGLE_LABEL}" >/dev/null 2>&1; }

if ! feature_on mouse_jiggle; then
  info "not enabled for $DOTFILES_MACHINE (machines/${DOTFILES_MACHINE}.conf)"
  # Only speak up if there is something to undo, so the common case is quiet.
  if jiggle_loaded || [[ -e "$JIGGLE_PLIST" ]]; then
    info "removing the jiggler this machine no longer wants..."
    # bootout before rm: deleting a loaded agent's plist leaves it running
    # until the next login, which is the half-removed state being avoided.
    launchctl bootout "gui/$(id -u)/${JIGGLE_LABEL}" 2>/dev/null || true
    rm -f "$JIGGLE_PLIST"
    ok "unloaded and removed"
  fi
  exit 0
fi

# cliclick is what actually moves the cursor. Loud rather than silent: without
# it the agent loads, runs, and does nothing, which looks like a broken flag.
if ! have cliclick; then
  warn "cliclick is not installed -- the jiggler would load and do nothing."
  warn "  brew install cliclick"
  exit 0
fi

# The plist is symlinked rather than copied, same as every other config here,
# so editing the repo edits the live agent. launchd still reads it only at
# bootstrap, so a change to the plist needs a bootout/bootstrap pair, not just
# a pull.
mkdir -p "$HOME/Library/LaunchAgents"
ln -sf "$DOTFILES_DIR/launchd/${JIGGLE_LABEL}.plist" "$JIGGLE_PLIST"

# Bootstrapping an already-loaded agent is an error rather than a no-op, so
# this asks first and stays re-runnable.
if jiggle_loaded; then
  ok "already loaded"
else
  info "loading..."
  if launchctl bootstrap "gui/$(id -u)" "$JIGGLE_PLIST"; then
    ok "loaded"
  else
    warn "couldn't load it -- launchctl bootstrap gui/$(id -u) '$JIGGLE_PLIST'"
  fi
fi

# First run needs Accessibility, and without it cliclick still exits 0 while
# the system discards the event -- so the script tests the OUTCOME and says so
# in its log rather than assuming a clean exit means it worked.
info "first run needs Accessibility; check ~/.cache/mouse-jiggle.log"
