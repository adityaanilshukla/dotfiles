#!/usr/bin/env bash

# Controller for all workspace indicators. One script run updates every
# `space.N` item: hidden if empty (unless focused), highlighted if focused,
# plain if it has windows. Driven by the aerospace_workspace_change event
# and a periodic update_freq so app open/close in any workspace is reflected.

source "$CONFIG_DIR/colors.sh"

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
NONEMPTY=$(aerospace list-workspaces --monitor all --empty no 2>/dev/null)

# Always render the focused workspace even when empty, so switching to an
# empty one doesn't leave the bar with no highlighted indicator.
SHOW=$(printf '%s\n%s\n' "$NONEMPTY" "$FOCUSED" | sort -u | grep -v '^$')

ARGS=()
for sid in 1 2 3 4 5 6 7 8 9 10; do
  if echo "$SHOW" | grep -qx "$sid"; then
    if [ "$sid" = "$FOCUSED" ]; then
      # polybar's label-active: white on blue-deep, square corners.
      ARGS+=(--set "space.$sid" drawing=on background.drawing=on background.color="$BLUE_DEEP" label.color="$PLAIN_WHITE")
    else
      # polybar's label-occupied: plain foreground, no background.
      ARGS+=(--set "space.$sid" drawing=on background.drawing=off label.color="$FOREGROUND")
    fi
  else
    ARGS+=(--set "space.$sid" drawing=off)
  fi
done

sketchybar "${ARGS[@]}"
