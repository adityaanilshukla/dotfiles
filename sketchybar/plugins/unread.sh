#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

# Unread counts for the apps people actually reach you on.
#
# Why this exists: this machine hides every surface macOS uses to say "someone
# is waiting". The Dock is autohidden, the menu bar is autohidden, and a banner
# gets one shot at your attention before it is gone for good. sketchybar is the
# only thing always on screen, so the count belongs here. A badge persists until
# you actually read the message, which is the property a notification lacks.
#
# `lsappinfo find bundleid=X` only matches RUNNING apps, and that limitation is
# the feature: an app that is not running is reported as such rather than as
# zero unread. Telegram has no aps-environment entitlement, so while it is quit
# it receives nothing and notifies you of nothing, silently. That state has to
# be visible, not inferred, so it is shown as loudly as a message count.
#
# No pinning to the Dock is required. A running app always has a Dock item.
#
# Every target is always shown, including zeros. An item that hides itself when
# there is nothing to report is indistinguishable from one that has broken, and
# this exists precisely so it can be trusted at a glance without opening the app
# to check.
#
# ----- Two badge mechanisms, not one -----
#
# There are two unrelated ways an app can put a number on its Dock icon, and
# which one it uses decides whether `lsappinfo` can see it:
#
#   AppKit    NSDockTile.badgeLabel  -> LaunchServices -> lsappinfo StatusLabel
#   Catalyst  UNUserNotificationCenter.setBadgeCount -> usernoted -> Dock
#
# Telegram and Zoho Mail are AppKit apps and take the first path. WhatsApp is a
# Catalyst app (UIDeviceFamily = (6), and usernoted logs it as isCatalyst: true)
# and takes the second, so LaunchServices holds nothing for it at all -- not an
# empty badge, no key whatsoever:
#
#   lsappinfo info -only StatusLabel <whatsapp>  ->  "StatusLabel"=[ NULL ]
#   lsappinfo info -only StatusLabel <zoho>      ->  "StatusLabel"={ "label"="" }
#
# That difference is the whole test. An absent key means LaunchServices has no
# opinion, so the count is asked of the Dock itself, which draws both kinds. An
# empty label means an app that does use LaunchServices is genuinely at zero.
#
# The Dock is queried through the accessibility API, which needs sketchybar to
# hold Accessibility permission. That is only spent on apps LaunchServices
# cannot answer for -- in practice one osascript call per cycle, for WhatsApp.
# Without the grant the app is shown as "?" rather than "0": not knowing and
# knowing there is nothing are different answers and must not look the same.

# bundle id : short label : name to match on the Dock item
TARGETS=(
  "net.whatsapp.WhatsApp:WA:WhatsApp"
  "ru.keepcoder.Telegram:TG:Telegram"
  "com.zoho.mail.desktop:Mail:Zoho Mail"
)

# Read the badge the Dock is drawing for an app, by name.
#
# perl's alarm is the timeout: macOS ships no timeout(1), and a wedged Dock must
# not stall the bar. Prints the count, or nothing for no badge, or DENIED when
# the accessibility grant is missing.
dock_badge() {
  local name="$1" out
  out=$(perl -e 'alarm 3; exec @ARGV' osascript -e "
    tell application \"System Events\" to tell process \"Dock\" to tell list 1
      value of attribute \"AXStatusLabel\" of (first UI element whose name contains \"$name\")
    end tell" 2>&1)

  case "$out" in
    *"not allowed assistive access"*|*"-1719"*) echo "DENIED" ;;
    *"missing value"*|*error*)                  ;;
    *)                                          echo "$out" ;;
  esac
}

parts=""
alert=0

for entry in "${TARGETS[@]}"; do
  bundle="${entry%%:*}"
  rest="${entry#*:}"
  short="${rest%%:*}"
  dock_name="${rest#*:}"

  asn=$(lsappinfo find "bundleid=$bundle" 2>/dev/null | head -1)
  if [ -z "$asn" ]; then
    # Not running. For Telegram this means messages arrive with no trace at all.
    parts+="${short}:off "
    alert=1
    continue
  fi

  # "StatusLabel"={ "label"="3" } when badged, "label"="" when not, and
  # "StatusLabel"=[ NULL ] when this app does not use LaunchServices at all.
  label=$(lsappinfo info -only StatusLabel "$asn" 2>/dev/null)
  if [ "${label#*NULL}" != "$label" ]; then
    # Catalyst app. LaunchServices knows nothing; ask the Dock what it draws.
    count=$(dock_badge "$dock_name")
    if [ "$count" = "DENIED" ]; then
      # Grant sketchybar Accessibility in System Settings > Privacy & Security.
      parts+="${short} ? "
      alert=1
      continue
    fi
  else
    count=$(printf '%s' "$label" | sed -n 's/.*"label"="\([^"]*\)".*/\1/p')
  fi

  if [ -n "$count" ]; then
    parts+="${short} ${count} "
    alert=1
  else
    # Running, nothing waiting. Shown as 0 rather than omitted: an app that
    # silently vanishes from the bar is indistinguishable from one that is
    # broken, and the whole point of this item is to be able to trust it at a
    # glance without opening anything.
    parts+="${short} 0 "
  fi
done

parts="${parts% }"

COLOR="$FOREGROUND"
[ "$alert" -eq 1 ] && COLOR="$BLUE_BRIGHT"
sketchybar --set "$NAME" drawing=on label="$parts" label.color="$COLOR"
