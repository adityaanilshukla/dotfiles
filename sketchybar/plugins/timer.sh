#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

# State written by `t` (scripts/t, on PATH as ~/Scripts/t):
#   <phase> <end_epoch> <phase_total_seconds> <next_break_seconds> <paused_remaining>
# phase is "work" or "break"; next_break_seconds is only meaningful mid-work,
# it's the break to chain into once work hits zero (0 = no break requested).
# paused_remaining is 0 while running; when >0 the timer is frozen at that
# many seconds and end_epoch is stale (ignored until `t pause` resumes it).
STATE_FILE="/tmp/sketchybar_timer.state"

if [[ ! -f "$STATE_FILE" ]]; then
  sketchybar --set "$NAME" drawing=off icon="" label=""
  exit 0
fi

read -r phase end phase_total next_break paused_remaining < "$STATE_FILE"
paused_remaining="${paused_remaining:-0}"

if (( paused_remaining > 0 )); then
  mins=$(( paused_remaining / 60 ))
  secs=$(( paused_remaining % 60 ))
  sketchybar --set "$NAME" drawing=on icon="$PLAY" icon.color="$GREY" label="$(printf '%02d:%02d' "$mins" "$secs")"
  exit 0
fi

now=$(date +%s)
remaining=$(( end - now ))

notify() {
  osascript -e "display notification \"$1\" with title \"Timer\" sound name \"Glass\"" >/dev/null 2>&1 &
}

# Current phase just finished: chain into the break, or clear back to idle.
if (( remaining <= 0 )); then
  if [[ "$phase" == "work" && "$next_break" -gt 0 ]]; then
    phase="break"
    phase_total="$next_break"
    end=$(( now + next_break ))
    remaining="$phase_total"
    echo "$phase $end $phase_total 0 0" > "$STATE_FILE"
    notify "Work done, break time"
  else
    rm -f "$STATE_FILE"
    if [[ "$phase" == "break" ]]; then
      notify "Break's over"
    else
      notify "Timer done"
    fi
    sketchybar --set "$NAME" drawing=off icon="" label=""
    exit 0
  fi
fi

mins=$(( remaining / 60 ))
secs=$(( remaining % 60 ))
pct=$(( remaining * 100 / phase_total ))

if [[ "$phase" == "break" ]]; then
  icon="$COFFEE"
  color="$GREEN"
elif (( pct >= 50 )); then
  icon="$HOURGLASS_START"
  color="$ACCENT_COLOR"
elif (( pct >= 20 )); then
  icon="$HOURGLASS_HALF"
  color="$YELLOW"
else
  icon="$HOURGLASS_END"
  color="$RED"
fi

sketchybar --set "$NAME" drawing=on icon="$icon" icon.color="$color" label="$(printf '%02d:%02d' "$mins" "$secs")"
