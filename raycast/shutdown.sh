#!/usr/bin/env bash
#
# Shut down, honouring "Reopen windows when logging back in".
#
# Raycast's built-in Shut Down does not. It sends the restart as an Apple Event
# with no state-saving parameter, and System Events' dictionary is explicit
# about what that means:
#
#   <parameter name="state saving preference" type="boolean" optional="yes"
#      description="Is the user defined state saving preference followed?">
#   If "state saving preference" is omitted or false, state is always saved.
#
# Omitted means "always save", not "use the checkbox". So every Raycast shut down
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
# @raycast.title Shut Down
# @raycast.mode silent
# @raycast.packageName Dotfiles
# @raycast.icon ⏻
# @raycast.description Shut down without macOS reopening every running app.

set -euo pipefail

osascript -e 'tell application "System Events" to shut down state saving preference true'
