#!/usr/bin/env bash
#
# One job: say what still needs a human, and make each item actionable.
#
# Split in two on purpose:
#
#   Permissions are delegated to macos/permissions.sh, which probes what is
#   actually granted and can walk you to the exact System Settings pane. That
#   is a different job from this one and is useful on its own months later, so
#   it lives in its own file rather than being inlined here.
#
#   Everything below is the remainder: steps that need a password, a browser
#   login, or a click inside another app's UI. None of them can be scripted,
#   but all of them can at least be stated with the exact command to run.
#
# This is called LAST so the list is the final thing on screen rather than
# scrolled off the top by several hundred lines of install output.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "What still needs you"

# --- Permissions ----------------------------------------------------------
# Checklist only: never the interactive walk. A step that blocks waiting for
# input would defeat the point of an installer you can start and walk away from.
if [[ -x "$DOTFILES_DIR/macos/permissions.sh" ]]; then
  "$DOTFILES_DIR/macos/permissions.sh" || true
else
  warn "macos/permissions.sh is missing — permissions cannot be checked."
fi

# --- Everything else ------------------------------------------------------
printf '%s  Manual steps%s\n\n' "$C_BOLD" "$C_OFF"

item() { printf '  %s•%s %s%s%s\n' "$C_YELLOW" "$C_OFF" "$C_BOLD" "$1" "$C_OFF"; }
detail() { printf '    %s%s%s\n' "$C_DIM" "$1" "$C_OFF"; }
cmd() { printf '      %s%s%s\n' "$C_GREEN" "$1" "$C_OFF"; }

item "Log out once"
detail "The screen-saver-never setting that stops this machine idle-sleeping"
detail "out from under a long session is applied, but loginwindow only reads"
detail "it at login. See BOOTSTRAP.md."
printf '\n'

item "Mint this machine's Turso token (zathura reading-state sync)"
cmd "make -C \$HOME/Projects/online-zathura join"
printf '\n'

# --- the zathura reader itself ----------------------------------------------
# The only CONDITIONAL item in this list, because unlike the rest its answer
# changes per machine and over time. Three states, two of which need saying:
#
#   no GTK4 build   optional. library and zp fall back to the brew GTK3 build,
#                   which opens everything and merely jitters when scrolling
#                   fullscreen on a Retina display. Offered, not demanded.
#   built, drifted  NOT optional. A plugin compiled against a different mupdf
#                   than the one installed refuses to create a context, so
#                   NOTHING opens -- and zathura answers by leaving an empty
#                   window up rather than exiting, so it presents as "my reader
#                   broke", not as a version skew. Homebrew upgrading mupdf is
#                   all it takes, and nothing else announces it.
#   built, in step  silence.
#
# This exists because the installer said nothing about either. The GTK4 build
# is documented only in BOOTSTRAP.md, which is not what you are looking at
# after a fresh install, and drift had no reporting path at all.
GTK4_ZATHURA="$HOME/.local/zathura-gtk4/bin/zathura"
CHECK_PLUGINS="$DOTFILES_DIR/scripts/check-zathura-plugins"

if [[ ! -x "$GTK4_ZATHURA" ]]; then
  item "Build the GTK4 zathura (optional, a few minutes of compiling)"
  detail "The homebrew tap is stuck on the last GTK3 release, whose macOS"
  detail "backend re-uploads the whole viewport every frame. Fullscreen on a"
  detail "Retina display visibly jitters while scrolling. Skipping this costs"
  detail "only that -- library and zp fall back to the brew build."
  cmd "$DOTFILES_DIR/scripts/build-zathura-gtk4"
  printf '\n'
elif [[ -x "$CHECK_PLUGINS" ]] && ! "$CHECK_PLUGINS" >/dev/null 2>&1; then
  item "Rebuild the zathura plugins -- they have drifted"
  detail "A plugin built against a different mupdf than the one installed"
  detail "refuses every document, and says so only in the launch log."
  "$CHECK_PLUGINS" 2>&1 | sed 's/^/    /' || true
  printf '\n'
fi

item "Tailscale: two steps, both needing a password"
detail "The daemon runs as root, so it is not a per-user launch agent."
detail "Without it, ssh/config hosts resolve by MagicDNS to nothing."
cmd "sudo brew services start tailscale"
cmd "sudo tailscale up --operator=$USER"
printf '\n'

item "Remote Login, so other machines can ssh in"
cmd "sudo systemsetup -setremotelogin on"
detail "If it answers that Full Disk Access is required, grant it to this"
detail "terminal — the permissions checklist above covers that."
printf '\n'

item "Install the Raycast extension 'Set Audio Device' (benvp/audio-device)"
detail "aerospace's alt-ctrl-z and the sketchybar audio glyph both deeplink"
detail "into it, and both do nothing until it is installed."
cmd "open 'raycast://extensions/benvp/audio-device'"
printf '\n'

item "Import the Vimium C config"
detail "Options > Backup and restore. The extension keeps its settings in"
detail "browser storage, so the file in this repo is a backup, not a config."
cmd "$DOTFILES_DIR/vimium_c-*.json"
printf '\n'

item "Browser-side keyboard config lives in the browser profile, not on disk"
detail "Set Dark Reader to Alt+Shift+D in about:addons > Manage Extension"
detail "Shortcuts, and paste the userscripts from ~/Projects/tampermonkey into"
detail "Tampermonkey. The Glove80 Alt chords in karabiner/spec.json drive both."
printf '\n'
