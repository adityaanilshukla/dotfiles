#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

# Detect connectivity from interface state — `networksetup -getairportnetwork`
# returns nothing on Tahoe without Location Services permission.
POWER=$(networksetup -getairportpower en0 2>/dev/null | awk '{print $NF}')
STATUS=$(ifconfig en0 2>/dev/null | awk '/status:/ {print $2}')

if [ "$POWER" = "Off" ] || [ "$STATUS" != "active" ]; then
  sketchybar --set "$NAME" icon="$WIFI_DISCONNECTED" icon.color="$RED" label=""
  exit 0
fi

# RSSI from system_profiler; format is "Signal / Noise: -58 dBm / -94 dBm".
# Slow (~1s) but doesn't need root or Location Services on Tahoe.
RSSI=$(system_profiler SPAirPortDataType 2>/dev/null \
  | awk -F: '/Signal \/ Noise/ {print $2; exit}' \
  | grep -oE '\-[0-9]+' | head -1)

# Map RSSI (dBm) to a color tier. Higher (less negative) is stronger.
if [ -z "$RSSI" ]; then
  COLOR="$WHITE"
elif [ "$RSSI" -ge -55 ]; then
  COLOR="$GREEN"
elif [ "$RSSI" -ge -65 ]; then
  COLOR="$WHITE"
elif [ "$RSSI" -ge -75 ]; then
  COLOR="$YELLOW"
elif [ "$RSSI" -ge -85 ]; then
  COLOR="$ORANGE"
else
  COLOR="$RED"
fi

sketchybar --set "$NAME" icon="$WIFI_CONNECTED" icon.color="$COLOR" label=""
