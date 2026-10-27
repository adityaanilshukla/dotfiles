#!/usr/bin/env bash
#
# One job: the agent that gives Qt apps a UI scale at login.
#
# Anki 26.9.3 ignores its own "User interface size" preference -- it saves the
# value and then applies it too late for Qt to read. See the plist for the
# upstream bug and for where the number lives.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Qt UI scale agent"

# Not opt-in per machine, unlike the jiggler: both machines run the same Anki
# build and both have the same bug, so there is nothing to disagree about. The
# scale itself is the one thing that is arguably per-machine, and it is a single
# number in the plist rather than a feature flag, because feature_on answers
# yes/no and not "how much". 90-retired-agents.sh stays the mechanism if this
# ever needs to come off a machine.
LABEL="com.aditya.dotfiles.qt-scale-factor"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

loaded() { launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; }

# Symlinked rather than copied, same as every other config here, so editing the
# repo edits the live agent. launchd reads the plist only at bootstrap, so a
# change to the scale still needs the bootout/bootstrap pair below.
mkdir -p "$HOME/Library/LaunchAgents"
ln -sf "$DOTFILES_DIR/launchd/${LABEL}.plist" "$PLIST"

# Re-bootstrap rather than skip when already loaded: the job's entire
# configuration is the number it passes to launchctl, so a pull that changes
# the scale has to reach launchd to mean anything. Bootstrapping an
# already-loaded agent is an error rather than a no-op, so bootout comes first.
if loaded; then
  info "reloading to pick up any scale change..."
  launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
fi

if launchctl bootstrap "gui/$(id -u)" "$PLIST"; then
  ok "loaded"
else
  warn "couldn't load it -- launchctl bootstrap gui/$(id -u) '$PLIST'"
fi

# RunAtLoad means the bootstrap above already ran it, so the variable is live in
# this login session now. Worth reporting the value rather than assuming it:
# this is the whole output of the job, and a silent failure here looks exactly
# like Anki's original bug.
#
# Read out of the gui/<uid> domain rather than with `launchctl getenv`, which is
# only honest when the caller is itself in the GUI session. From anywhere that
# is not -- an ssh login, a tmux server inherited from an older session, a shell
# launched by a daemon -- getenv queries a different domain and reports nothing
# while the variable is in fact set, so the check would fail on a working
# install. `launchctl print gui/<uid>` names the domain explicitly and does not
# have that ambiguity.
scale="$(launchctl print "gui/$(id -u)" 2>/dev/null |
         sed -n 's/^[[:space:]]*QT_SCALE_FACTOR => //p')"
if [[ -n "$scale" ]]; then
  ok "QT_SCALE_FACTOR=$scale"
  info "apps already running keep their old size until restarted"
else
  warn "QT_SCALE_FACTOR is not set -- the agent ran but the variable did not stick"
fi
