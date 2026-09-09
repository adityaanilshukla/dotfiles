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
# to check. A quiet app is a dimmed letter rather than a missing one: still
# present, still countable, visibly saying nothing is waiting.
#
# ----- Why three items and not one label -----
#
# A sketchybar label is one colour for its whole length, so a single item can
# only ever say "something, somewhere, is waiting". Splitting into one item per
# app is what lets the colour name WHICH app, which is the entire glance-value
# of this thing. The script itself is an invisible fourth item that drives the
# other three, the same shape aerospace_controller uses for the ten workspace
# items, and for the same reason: one script call, several drawn items.
#
# State is carried by colour and by whether a number is present at all:
#
#   count > 0     bright blue letter + the number
#   running, 0    dimmed letter, no number
#   not running   magenta letter, no number
#   grant missing yellow letter + "?"
#
# Not-running keeps a loud colour rather than the dim one. It is not a quiet
# state: Telegram quit means messages arrive nowhere and announce nothing, and
# that has to look like an alarm, not like an empty inbox.
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

# bundle id : item name : letter : name to match on the Dock item
TARGETS=(
  "net.whatsapp.WhatsApp:unread.whatsapp:W:WhatsApp"
  "ru.keepcoder.Telegram:unread.telegram:T:Telegram"
  "com.zoho.mail.desktop:unread.mail:M:Zoho Mail"
)

# Read the badge the Dock is drawing for an app, by name.
#
# perl's alarm is the timeout: macOS ships no timeout(1), and a wedged Dock must
# not stall the bar. Prints the count, or nothing for no badge, or DENIED when
# the accessibility grant is missing.
#
# stderr is folded in on purpose: a denied accessibility grant is reported there
# and nowhere else, and losing it would turn a permissions failure into a silent
# "no badge" -- the one outcome this item exists to make impossible to miss.
#
# The cost of that merge is that osascript unconditionally logs a line like
#
#   2026-09-08 10:10:42.176 osascript[62436:26473806] ApplePersistence=NO
#
# to stderr on every single run. Both error cases match on a substring so they
# survive it, but a real badge does not: echoing the merged stream whole put
# that log line on the bar in front of the count. So classify on everything,
# and extract the value only from the lines osascript did not write itself.
# Matching the timestamped prefix rather than ApplePersistence by name keeps
# any future chatter of the same shape out too.
dock_badge() {
  local name="$1" out
  out=$(perl -e 'alarm 3; exec @ARGV' osascript -e "
    tell application \"System Events\" to tell process \"Dock\" to tell list 1
      value of attribute \"AXStatusLabel\" of (first UI element whose name contains \"$name\")
    end tell" 2>&1)

  # AppleScript overloads -1719: it is the assistive-access denial, and it is
  # also "Invalid index", returned when no Dock item matches the name. Those
  # need opposite answers, so the not-found reading is taken off the table
  # first. -1719 is still trusted for denial afterwards rather than relying on
  # the message text alone, because mistaking a denial for a zero is the one
  # error this item must never make.
  case "$out" in
    *"Invalid index"*)                          ;;
    *"not allowed assistive access"*|*"-1719"*) echo "DENIED" ;;
    *"missing value"*|*error*)                  ;;
    *) printf '%s\n' "$out" | grep -v '^[0-9-]\{10\} [0-9:.]* osascript\[' ;;
  esac
}

# One --set per app, all handed to sketchybar in a single call at the end.
# Three separate calls would repaint the group in three steps and flicker.
args=()

# paint <item> <letter> <colour> [number]
paint() {
  args+=(--set "$1"
         icon="$2" icon.color="$3"
         label="${4-}" label.color="$3")
}

for entry in "${TARGETS[@]}"; do
  # Safe as a plain split: no field contains a colon, and only the last one
  # contains a space, which `read` leaves alone once the earlier fields are
  # consumed. Peeling these off with ${x%%:*} / ${x#*:} took six lines and grew
  # a line every time a field was added.
  IFS=: read -r bundle item letter dock_name <<< "$entry"

  asn=$(lsappinfo find "bundleid=$bundle" 2>/dev/null | head -1)
  if [ -z "$asn" ]; then
    # Not running. For Telegram this means messages arrive with no trace at all,
    # so it is coloured as an alarm rather than dimmed like a quiet app.
    paint "$item" "$letter" "$ALERT"
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
      paint "$item" "$letter" "$WARNING" "?"
      continue
    fi
  else
    count=$(printf '%s' "$label" | sed -n 's/.*"label"="\([^"]*\)".*/\1/p')
  fi

  if [ -n "$count" ]; then
    paint "$item" "$letter" "$BLUE_BRIGHT" "$count"
  else
    # Running, nothing waiting. Dimmed rather than dropped: an app that silently
    # vanishes from the bar is indistinguishable from one that is broken, and
    # the whole point of this is to be trusted at a glance without opening
    # anything.
    paint "$item" "$letter" "$DISABLED"
  fi
done

sketchybar "${args[@]}"
