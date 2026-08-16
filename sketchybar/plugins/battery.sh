#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

# Mirrors polybar's [module/battery]: one glyph for charging, another for
# running on battery, coloured by state rather than by charge level. polybar
# has no per-level ramp, so neither does this.
#
# Deviation, deliberate: polybar's config sets low-at = 5 but never defines a
# format-low, so a nearly flat battery looks the same as a full one there. On
# a laptop that is a real blind spot, so <= 10% goes red here. Drop the last
# case below to match polybar byte for byte.

PERCENTAGE=$(pmset -g batt | grep -Eo '\d+%' | cut -d% -f1)
CHARGING=$(pmset -g batt | grep 'AC Power')

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

if [ -n "$CHARGING" ]; then
  ICON=$BATTERY_CHARGING
  COLOR=$SUCCESS
elif [ "$PERCENTAGE" -ge 99 ]; then
  ICON=$BATTERY
  COLOR=$SUCCESS
elif [ "$PERCENTAGE" -le 10 ]; then
  ICON=$BATTERY
  COLOR=$ALERT
else
  ICON=$BATTERY
  COLOR=$WARNING
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="${PERCENTAGE}%"
