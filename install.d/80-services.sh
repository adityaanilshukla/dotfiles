#!/usr/bin/env bash
#
# One job: background services.
#
# Launch agents, and reporting the two daemons that need a password.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Background services"

# Installing sketchybar and symlinking its config is not enough: it runs as a
# launch agent, so without this a fresh machine has the bar fully configured
# and simply no bar on screen. Starting an already-started service is harmless,
# so this stays idempotent.
for svc in sketchybar syncthing; do
  # Loud, not `|| continue`. This silently did nothing for sketchybar on a real
  # install and the bar simply never appeared.
  if ! command -v "$svc" >/dev/null 2>&1; then
    echo "  !! $svc is not installed — service not started."
    echo "     Install it, then: brew services start $svc"
    continue
  fi
  if ! brew services list 2>/dev/null | grep -qE "^${svc}[[:space:]]+started"; then
    echo "Starting $svc service..."
    brew services start "$svc" >/dev/null \
      || echo "  couldn't start $svc — run 'brew services start $svc'"
  fi
done

# Tailscale is deliberately NOT in the loop above. Its daemon has to run as
# root — it opens a utun interface and rewrites the system DNS resolvers for
# MagicDNS, neither of which a per-user LaunchAgent can do — so it is
# `sudo brew services start tailscale`, landing in /Library/LaunchDaemons
# rather than ~/Library/LaunchAgents where the loop looks. Joining the tailnet
# is a browser login on top of that.
#
# So this only reports. An install script that stops to ask for a password
# halfway through is worse than one that tells you the two commands, and the
# failure it is guarding against is quiet: ssh/config resolves its hosts by
# MagicDNS, so with no daemon `ssh brovo` fails with "could not resolve
# hostname" and looks like a broken config rather than a service that is off.
if command -v tailscale >/dev/null 2>&1 && ! tailscale status >/dev/null 2>&1; then
  echo "  !! tailscale is installed but not connected — 'ssh brovo' cannot resolve."
  echo "     sudo brew services start tailscale"
  echo "     sudo tailscale up --operator=$USER"
fi

# Remote Login (sshd), so the other machines can copy FROM this one. Checked by
# opening a socket rather than by asking systemsetup, which needs admin rights
# just to read the setting, and rather than by lsof, which would not show a
# root-owned listener to an unprivileged user and would report every machine as
# off.
if ! nc -z 127.0.0.1 22 >/dev/null 2>&1; then
  echo "  !! Remote Login is off — nothing can ssh or scp INTO this Mac."
  echo "     sudo systemsetup -setremotelogin on"
fi

# AeroSpace does not come up on its own. Installing a cask does not launch it,
# and `start-at-login = true` in aerospace.toml only registers a login item
# once the app has run once — so on a fresh machine the setting reads as
# ignored: reboot, and there is no window manager and nothing tiles.
#
# Launching it here is also what raises the Accessibility prompt, which is the
# part that genuinely cannot be scripted. Raising it during install means it is
# sitting there waiting rather than being discovered weeks later when
# alt-shift-x silently does nothing.
#
# -g so it does not steal focus mid-install, and `open -a` on an already
# running app just activates it, so this stays idempotent like everything else.
if [[ -d /Applications/AeroSpace.app ]]; then
  echo "Launching AeroSpace (registers start-at-login, raises the Accessibility prompt)..."
  open -g -a AeroSpace || echo "  couldn't launch AeroSpace — open it by hand."
else
  echo "  !! AeroSpace is not installed — not launched, so start-at-login is not"
  echo "     registered and the Accessibility prompt has not been raised."
fi
