#!/usr/bin/env bash
# macOS `defaults` settings.
#
# These live in cfprefsd's preferences database (~/Library/Preferences/*.plist),
# which the daemon caches and rewrites on its own — so they can't be symlinked
# like a normal dotfile. Instead we re-apply the `defaults write` commands on a
# new machine. install.sh runs this script.
set -euo pipefail

# VS Code: disable the press-and-hold accent popup so a held key repeats
# instead. Needed for Vim-style navigation (holding h/j/k/l) in VSCodeVim.
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

# Alacritty: turn off Core Text's stroke thickening. With no value set macOS
# applies full smoothing, which fattens every glyph and reads as blurry on a
# non-Retina external display. Measured on the Dell at font size 20: unset and
# 3 are indistinguishable (~8500 lit pixels), 0 drops to ~6950, i.e. 19% fewer
# lit pixels and visibly thinner strokes.
#
# Scoped to org.alacritty on purpose, so it doesn't restyle the rest of the OS.
# Alacritty reads it once at process start, so a new window is not enough: quit
# with Cmd-Q and relaunch.
defaults write org.alacritty AppleFontSmoothing -int 0

# Nothing reopens at login. macOS TAL ("Terminate and Live" — the "Reopen
# windows when logging back in" checkbox) relaunches whatever was running at
# shutdown, which meant arriving at a desktop full of Brave and Alacritty
# windows placed wherever AeroSpace happened to put them.
#
# The checkbox alone does not fix it, and neither does TALLogoutSavesState:
# both were already off here while loginwindow still restored six apps. The
# reason is that the checkbox is only consulted on the dialog path. Restart
# from Raycast (or any scripted restart) arrives as an Apple Event, and
# loginwindow logs what it does with it:
#
#   Received a kAERestart
#   Calling to start a logout with NO UI
#   showConfirmation:0, currentTALOption:1 - TALRestore
#
# showConfirmation:0 means the dialog carrying the checkbox is never drawn, and
# TALRestore is the hardcoded fallback for that path. Nothing user-facing can
# change it.
#
# ApplePersistence sits upstream of all of that. From loginwindow's own binary:
#
#   ApplePersistence = -1 or 0 setting returnAppsEnabled to NO prefValue:%ld
#
# returnAppsEnabled is what -[PersistentAppsSupport persistentAppsEnabled]
# returns, and it gates the relaunch before the TAL option is ever consulted.
# Set to 0 the whole subsystem is off, so it no longer matters who triggers the
# restart or which Apple Event parameters they omit.
#
# Verify after a restart with:
#   log show --last 10m --predicate 'process == "loginwindow"' \
#     | grep -E "returnAppsEnabled|previouslyRunningApps count"
# Wanted: returnAppsEnabled set to NO, and previouslyRunningApps count:0.
#
# Cost: this is the global Resume switch, so it also stops apps restoring their
# own windows and documents when you reopen them — Preview will not come back
# to the PDFs you had open. That is the same thing being asked for, one level
# down, and is the trade.
defaults write -g ApplePersistence -bool false

# Ctrl+Left / Ctrl+Right: give them back to the terminal.
#
# macOS binds both system-wide to Mission Control's "Move left/right a space"
# (symbolic hotkeys 79 and 81). A registered symbolic hotkey is consumed before
# the frontmost application is offered the event, so Ctrl+Arrow never reached
# Alacritty at all. That is why word navigation looked broken everywhere at once
# rather than in one program, and why nothing downstream was at fault: Karabiner
# already excludes terminals from its own Ctrl+Arrow rule, alacritty sends
# \e[1;5D and \e[1;5C, and oh-my-zsh binds both to backward-word/forward-word.
# Verified with `bindkey "^[[1;5C"` under every TERM this machine uses.
#
# Nothing is lost by turning them off. AeroSpace manages workspaces itself and
# does not use native macOS spaces, so the shortcut had nothing to switch
# between here.
#
# 80 and 82 (Ctrl+Shift+Arrow, "move window to a space") are deliberately left
# alone. They collide with nothing a terminal wants.
#
# Replacing each entry wholesale is lossless: both hold only {enabled = 1} and
# carry no custom key binding to preserve. Written with `defaults` rather than
# by editing the plist, because cfprefsd owns that file and would overwrite it.
for hotkey in 79 81; do
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
    -dict-add "$hotkey" '<dict><key>enabled</key><false/></dict>'
done

# The top row sends real function keys.
#
# Neovim binds <F7> to its floating terminal and it did nothing, on the built-in
# keyboard AND on the Glove80. The cause is one layer lower than it looks.
#
# macOS draws the media functions over the top row of APPLE keyboards. Karabiner
# grabs every physical keyboard and re-emits the events through its own virtual
# device, and that device reports Apple's vendor id (1452), so macOS applies the
# overlay to everything Karabiner passes on - including the Glove80, whose f7
# was correct all along. The overlay is downstream of Karabiner, which is why no
# Karabiner rule could win: a complex modification from f7 to f7 changed
# nothing, and neither did the fn_function_keys table. Both were measured, not
# assumed. fnState is the only switch upstream of the overlay.
#
# On its own this is heavy-handed - it takes brightness, mission control and
# volume off a bare press for the sake of one key - so karabiner/spec.json puts
# them straight back with an explicit rule per key. Every one is restored except
# f7. Net cost is previous-track, plus fn+F-key now giving a literal function
# key rather than a media one.
#
# The two halves are load-bearing together: this line without the Karabiner
# rules leaves the row dead, and the rules without this line do nothing at all.
defaults write -g com.apple.keyboard.fnState -bool true

# The hotkey table is read once and cached, so without this the change does not
# reach the WindowServer until the next login. Not fatal if it fails: the write
# above is the part that persists, and a login applies it anyway. This script
# runs under `set -e`, so the guard is what keeps a cosmetic refresh from
# aborting everything after it.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u \
  || echo "  !! activateSettings failed — Ctrl+Left/Right and the function-key row take effect at the next login."

# Key repeat: faster, and in step with the display.
#
# Both values are in sixtieths of a second. The factory default, read off the
# live HID event system rather than guessed at:
#
#   ioreg -c IOHIDSystem -r -d 1 | grep -E "HIDKeyRepeat|HIDInitialKeyRepeat"
#   HIDInitialKeyRepeat = 500000000 ns   (30/60s)
#   HIDKeyRepeat        =  83333333 ns   ( 5/60s = 12 repeats/second)
#
# 12 a second is slow enough that holding j or k in nvim crawls. It is also the
# reason the scrolling looked JITTERY rather than merely slow, which is the part
# worth writing down, because the fix is not simply "make it faster".
#
# A line can only appear on a frame boundary. On the 100Hz Dell a frame is 10ms,
# and an 83.33ms step is 8 and 1/3 frames — so the gaps you actually see
# alternate 80, 90, 80, 80, 90, and every third line hangs 12.5% longer than its
# neighbours. Same shape as 3:2 pulldown judder, and 12Hz sits right where the
# eye is worst at tolerating an uneven cadence. (Alacritty compounds this: it
# does not vsync on macOS, pacing frames off its own free-running timer instead,
# so a second unsynchronised quantiser stacks on the first.)
#
# Only repeat rates whose step is a whole number of frames come out even. At
# 100Hz that means multiples of 3:
#
#   n=2   33.3ms   30/sec   gaps 30,40   <- faster, still beats
#   n=3   50.0ms   20/sec   gaps 50      <- even
#   n=5   83.3ms   12/sec   gaps 80,90   <- the default, the problem
#   n=6  100.0ms   10/sec   gaps 100     <- even but slower than the default
#
# n=3 is the only value that is both quicker and evenly paced, so that is the
# one set here: 67% faster AND smooth. Turning the System Settings slider to its
# maximum would give 30/sec and put the beat straight back.
#
# This is tuned to a 100Hz panel. On a 60Hz display every value divides evenly
# and the choice is purely about speed.
defaults write -g KeyRepeat -int 3
defaults write -g InitialKeyRepeat -int 15

echo "Applied macOS defaults. Restart affected apps to pick them up:"
echo "  - VS Code (press-and-hold)"
echo "  - Alacritty, full Cmd-Q and relaunch (font smoothing)"
echo "  - nothing else; ApplePersistence takes effect at the next restart"
echo "Ctrl+Left/Right are released from Mission Control and work immediately."
echo "The top row sends F1-F12; karabiner/install.sh restores the media keys"
echo "  on every one of them except F7, which Neovim wants."
echo "Key repeat is 20/sec — that one needs a logout before it applies."
