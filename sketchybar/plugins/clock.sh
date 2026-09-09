#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

# Matches polybar's [module/date]: `date = %a %b %d %H:%M`, calendar glyph in
# blue. Month before day, unlike the previous macOS-only format.
#
# The glyph is set here rather than once in sketchybarrc even though it never
# changes. Every other item's icon is chosen by its plugin, and having one
# exception meant you had to check two files to find where a glyph came from.
sketchybar --set "$NAME" \
  icon="$CALENDAR" icon.color="$BLUE_BRIGHT" \
  label="$(date '+%a %b %d %H:%M')"
