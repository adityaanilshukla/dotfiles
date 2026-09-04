#!/usr/bin/env bash
#
# Restart, honouring "Reopen windows when logging back in".
#
# Raycast's built-in Restart does not. It sends the restart as an Apple Event
# with no state-saving parameter, and System Events' dictionary is explicit
# about what that means:
#
#   <parameter name="state saving preference" type="boolean" optional="yes"
#      description="Is the user defined state saving preference followed?">
#   If "state saving preference" is omitted or false, state is always saved.
#
# Omitted means "always save", not "use the checkbox". So every Raycast restart
# reopened every running app regardless of the setting, and the setting could
# not be seen to be wrong because the dialog that carries it was never drawn.
# loginwindow logs the whole thing at logout:
#
#   Received a kAERestart
#   Calling to start a logout with NO UI
#   showConfirmation:0, currentTALOption:1 - TALRestore
#
# and again at the next boot, as previouslyRunningApps with hiddenFlag:0 per
# app, which is why they came back visible.
#
# Passing the parameter as true is the whole fix. The checkbox in the  >
# Restart… dialog is then read as written; it is already unticked.
#
# Not in ~/Scripts, deliberately. That directory is the alt-x launcher's menu
# and the launcher execs whatever is highlighted the moment you press enter,
# so an unattended restart is one stray keystroke away. Raycast at least makes
# you type the name.

# @raycast.schemaVersion 1
# @raycast.title Restart
# @raycast.mode silent
# @raycast.packageName Dotfiles
# @raycast.icon 🔄
# @raycast.description Restart without macOS reopening every running app.

set -euo pipefail

# Confirm first. Raycast fires a script command the instant you press enter on
# it and offers no confirmation of its own, so without this the machine goes
# down on one keystroke, from a list where the neighbouring entries are things
# like Restore and Restart Audio.
#
# `activate` is load-bearing. Without it the dialog belongs to a background
# osascript and can open *behind* whatever you are looking at, which is worse
# than no confirmation: the machine appears to hang, then restarts when you
# eventually find and answer the box.
#
# Default button is Cancel, so enter dismisses and restarting takes a deliberate
# click. Swap `default button` to "Restart" if you would rather enter confirmed;
# that still costs two enters rather than one.
#
# `giving up after` bounds an unattended dialog. It returns an empty string,
# which is not "Restart", so the timeout falls through to the safe path.
CHOICE=$(osascript <<'APPLESCRIPT'
tell application "System Events"
  activate
  try
    button returned of (display dialog "Restart now?" buttons {"Cancel", "Restart"} default button "Cancel" with icon caution with title "Restart" giving up after 30)
  on error
    ""
  end try
end tell
APPLESCRIPT
)

[ "$CHOICE" = "Restart" ] || exit 0

osascript -e 'tell application "System Events" to restart state saving preference true'
