#!/usr/bin/env bash
#
# One job: the agent that revives menu-bar helpers a brew upgrade killed.
#
# See scripts/relaunch-menubar-apps for why that is needed at all, and
# install.d/85-login-items.sh for the login half of the same problem.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Menu-bar helper relaunch agent"

# Not opt-in per machine, unlike the jiggler: both machines run the same three
# helpers and both lose them the same way, so there is nothing to disagree
# about. 90-retired-agents.sh stays the mechanism if that ever changes.
LABEL="com.aditya.dotfiles.relaunch-menubar-apps"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

loaded() { launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; }

# Symlinked rather than copied, same as every other config here, so editing the
# repo edits the live agent. launchd still reads the plist only at bootstrap, so
# a change to it needs the bootout/bootstrap pair below and not just a pull.
mkdir -p "$HOME/Library/LaunchAgents"
ln -sf "$DOTFILES_DIR/launchd/${LABEL}.plist" "$PLIST"

# Re-bootstrap rather than skip when already loaded. The job's whole
# configuration is its WatchPaths list, so a pull that adds an app to that list
# has to reach launchd to mean anything -- and bootstrapping an already-loaded
# agent is an error rather than a no-op, so the bootout has to come first.
if loaded; then
  info "reloading to pick up any WatchPaths change..."
  launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
fi

if launchctl bootstrap "gui/$(id -u)" "$PLIST"; then
  ok "loaded"
else
  warn "couldn't load it -- launchctl bootstrap gui/$(id -u) '$PLIST'"
fi

# RunAtLoad means the bootstrap above already did a pass, so anything that was
# dead is back by now. Nothing to verify here; the script logs only when it
# actually relaunched something.
info "log: ~/.cache/relaunch-menubar-apps.log (quiet unless it revives something)"
