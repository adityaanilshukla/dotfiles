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
# The count is the Dock badge, read via `lsappinfo`, which needs no permissions
# at all. That is why this does NOT walk the Dock's accessibility tree: that
# works too (AXStatusLabel on a dock item, verified), but it would have meant
# granting sketchybar Accessibility, and lsappinfo makes the grant unnecessary.
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

# bundle id : short label on the bar
TARGETS=(
  "net.whatsapp.WhatsApp:WA"
  "ru.keepcoder.Telegram:TG"
  "com.zoho.mail.desktop:Mail"
)

parts=""
alert=0

for entry in "${TARGETS[@]}"; do
  bundle="${entry%%:*}"
  short="${entry##*:}"

  asn=$(lsappinfo find "bundleid=$bundle" 2>/dev/null | head -1)
  if [ -z "$asn" ]; then
    # Not running. For Telegram this means messages arrive with no trace at all.
    parts+="${short}:off "
    alert=1
    continue
  fi

  # "StatusLabel"={ "label"="3" } when badged, "label"="" when not.
  count=$(lsappinfo info -only StatusLabel "$asn" 2>/dev/null \
          | sed -n 's/.*"label"="\([^"]*\)".*/\1/p')
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
