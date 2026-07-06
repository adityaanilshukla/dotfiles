#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"

# Where we cache which display currently carries audio, so the steady-state
# poll is a single fast BetterDisplay query instead of re-enumerating displays.
CACHE="/tmp/sketchybar_ddc_speaker"

# read_ddc <display-name> -> prints 0–100 percent and returns 0 on success.
# BetterDisplay reports the DDC speaker level as a 0.0–1.0 float; anything
# non-numeric (empty, "Failed.") means that display has no readable audio.
read_ddc() {
  local bd
  bd=$(betterdisplaycli get --name="$1" --volume 2>/dev/null)
  case "$bd" in
    ''|*[!0-9.]*) return 1 ;;
    *) awk -v v="$bd" 'BEGIN { printf "%d", v * 100 + 0.5 }'; return 0 ;;
  esac
}

# INFO is set by the volume_change event (macOS software volume, an integer).
# On a periodic refresh INFO is empty, so read the current output volume.
VOLUME="$INFO"
[ -z "$VOLUME" ] && VOLUME=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)

case "$VOLUME" in
  ''|*[!0-9]*)
    # Non-numeric ("missing value"): the active output is a DDC-controlled
    # display with no macOS software volume (e.g. a monitor over DisplayPort).
    # Its level lives in the monitor's DDC audio register — read it via
    # BetterDisplay. Try the cached display first; if it no longer reports a
    # volume (output switched or unplugged), enumerate connected displays and
    # pick the one that does, caching it for next time.
    VOLUME=0
    DISP=$(cat "$CACHE" 2>/dev/null)
    if [ -n "$DISP" ] && PCT=$(read_ddc "$DISP"); then
      VOLUME="$PCT"
    else
      while IFS= read -r d; do
        [ -z "$d" ] && continue
        if PCT=$(read_ddc "$d"); then
          VOLUME="$PCT"
          printf '%s' "$d" >"$CACHE"
          break
        fi
      done <<EOF
$(betterdisplaycli get --identifiers 2>/dev/null | sed -n 's/.*"name" : "\([^"]*\)".*/\1/p')
EOF
    fi
    ;;
esac

case "$VOLUME" in
  100|9[0-9]|8[0-9]|7[0-9]) ICON=$VOLUME_100 ;;
  6[0-9]|5[0-9]|4[0-9])     ICON=$VOLUME_66  ;;
  3[0-9]|2[0-9])            ICON=$VOLUME_33  ;;
  1[0-9])                   ICON=$VOLUME_10  ;;
  *)                        ICON=$VOLUME_0   ;;
esac

sketchybar --set "$NAME" icon="$ICON" label="${VOLUME}%"
