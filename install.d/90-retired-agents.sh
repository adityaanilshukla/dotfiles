#!/usr/bin/env bash
#
# One job: removing retired launchagents.
#
# Deleting an agent from this repo does not delete it from a machine that
# already has one. Retiring means naming it here.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Removing retired LaunchAgents"

# Removing a LaunchAgent from this repo does not remove it from a machine that
# already has one. 78e69bc deleted scripts/start-comms, its plist and the block
# that installed it, but a copy already sitting in ~/Library/LaunchAgents stays
# there and stays loaded -- so on the machine that had been installed before
# that commit, the comms apps carried on launching at login for days after the
# repo said they should not. The repo looked right and the machine disagreed,
# which is the failure mode this file exists to prevent.
#
# So retiring an agent means naming it here, not just deleting it. Entries stay
# for as long as any machine might still be carrying the old copy; there is no
# cost to leaving one in place once every machine is clean, since the loop skips
# anything already absent.
#
# The plists themselves are recoverable from git history if one turns out to
# have been retired in error -- start-comms is at e4305f9.
retired_agents=(
  "com.aditya.dotfiles.start-comms"   # retired by 78e69bc: nothing starts at login
)
for label in "${retired_agents[@]}"; do
  plist="$HOME/Library/LaunchAgents/${label}.plist"
  [[ -e "$plist" ]] || continue
  echo "Removing retired LaunchAgent ${label}..."
  # bootout first: deleting a loaded agent's plist leaves it running until the
  # next login, which is the same half-removed state this block is fixing.
  launchctl bootout "gui/$(id -u)/${label}" 2>/dev/null || true
  rm -f "$plist"
done
