#!/usr/bin/env bash

# Matches polybar's [module/date]: `date = %a %b %d %H:%M`, calendar glyph in
# blue. Month before day, unlike the previous macOS-only format.
sketchybar --set "$NAME" label="$(date '+%a %b %d %H:%M')"
