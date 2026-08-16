#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

# Mirrors polybar's [module/wlan] via network.sh: a single blue glyph, and the
# module disappears entirely when the interface is down. polybar also hides
# wifi when ethernet is the interface carrying the default route, so the same
# check is done here with `route -n get default`.
#
# Note this drops the RSSI-tinted colour tiers the macOS version used to have.
# polybar has no equivalent, and the signal strength came from a
# system_profiler call that took about a second on every poll, so losing it
# makes the bar cheaper as well as more faithful.

# Detect connectivity from interface state: `networksetup -getairportnetwork`
# returns nothing on Tahoe without Location Services permission.
POWER=$(networksetup -getairportpower en0 2>/dev/null | awk '{print $NF}')
STATUS=$(ifconfig en0 2>/dev/null | awk '/status:/ {print $2}')

if [ "$POWER" = "Off" ] || [ "$STATUS" != "active" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# If something else carries the default route (dock ethernet, say), let the
# wired module speak instead, exactly as polybar's network.sh does.
PRIMARY=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
if [ -n "$PRIMARY" ] && [ "$PRIMARY" != "en0" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

sketchybar --set "$NAME" drawing=on icon="$WIFI" icon.color="$BLUE_BRIGHT" label=""
