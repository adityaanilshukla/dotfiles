#!/usr/bin/env bash
#
# One job: login items.
#
# Apps that must run at login but cannot register themselves.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Login items"

# Apps that have to be running for this machine to behave as configured, but
# which cannot be made to start themselves.
#
# AeroSpace, Raycast and BetterDisplay are not here because they do not need to
# be: each has its own start-at-login setting and registers itself the first
# time it runs, which is what the `open -g -a` above is for.
#
# Scroll Reverser and KeyClu have no such setting. Checked rather than assumed:
# Scroll Reverser 1.9 has no StartAtLogin key in com.pilotmoon.scroll-reverser
# and no Contents/Library/LoginItems helper in the bundle, so launching it
# registers nothing. Left alone, both are installed by the Brewfile, appear to
# be set up, and simply are not running after a reboot -- which is exactly how
# this was found: reverse scrolling silently stopped working and had to be
# started by hand from Raycast, weeks after the install.
#
# Wispr Flow is here for a different reason: it DOES have the setting, and the
# setting is already on -- its own config.json carries "openAtLogin": true --
# but the registration that setting is supposed to create is not there. Being
# an Electron app it asks via SMAppService, which lands in the Background Task
# Management database (System Settings > General > Login Items & Extensions,
# under "Allow in the Background") rather than in the login-item list this
# script writes to. That database needs root to inspect, so why the request did
# not stick is not answerable from here -- but a classic login item does not
# depend on it and works regardless.
#
# Registering both is harmless: macOS activates the running instance rather
# than launching a second copy of the same bundle, so the worst case when the
# SMAppService side is working after all is that the app is asked to start
# twice and starts once.
#
# Worth having rather than shrugging at, because a Wispr that is not running is
# not a dictation app that is merely inconvenient -- it is the F13 push-to-talk
# rule in karabiner/spec.json silently doing nothing, which reads as a broken
# keyboard remap rather than an app that is not open.
#
# `make login item` keys on the path, so adding one twice replaces rather than
# duplicates -- verified, not assumed. The presence check below is only so the
# script says something true about what it did.
#
# hidden:true asks for nothing to flash at login. Do not lean on it: System
# Events reports `hidden` as false for all three afterwards, whatever was
# passed, so it is a request rather than a guarantee. It costs nothing and may
# be honoured, so it stays.
#
# It matters least where it was first used: Scroll Reverser and KeyClu are
# menu-bar-only (LSUIElement), so there is no window to show either way. Wispr
# Flow is not -- it has no LSUIElement key -- so it is the one that could
# actually put something on screen at login.
#
# First run may raise an Automation prompt for System Events. That is the same
# bargain as the Accessibility prompt above: better surfaced now than
# discovered later when the machine quietly does not do what it should.
login_items="$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null)"
for app in "Scroll Reverser" "KeyClu" "Wispr Flow"; do
  if [[ ! -d "/Applications/${app}.app" ]]; then
    echo "  !! $app is not installed — not registered to start at login."
    continue
  fi
  if [[ "$login_items" == *"$app"* ]]; then
    continue
  fi
  echo "Registering $app to start at login..."
  osascript -e "tell application \"System Events\" to make login item at end \
                with properties {path:\"/Applications/${app}.app\", hidden:true}" \
    >/dev/null 2>&1 \
    || echo "  couldn't register $app — add it by hand in System Settings > General > Login Items."
done
