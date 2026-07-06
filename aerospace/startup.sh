#!/bin/sh
# Place apps restored by macOS from the previous session onto their
# assigned workspaces at AeroSpace startup. Does not launch anything;
# if an app isn't running, it's skipped. After startup, windows can be
# moved freely — this only runs once via after-startup-command.

# Give macOS a moment to finish resurrecting apps from the previous session.
sleep 5

move_app() {
  bundle_id="$1"
  workspace="$2"
  aerospace list-windows --all --app-bundle-id "$bundle_id" --format '%{window-id}' 2>/dev/null \
    | while read -r wid; do
        [ -n "$wid" ] && aerospace move-node-to-workspace --window-id "$wid" "$workspace"
      done
}

move_app "org.alacritty"         1
move_app "com.brave.Browser"     2
move_app "ru.keepcoder.Telegram" 3
move_app "com.microsoft.Outlook" 4
