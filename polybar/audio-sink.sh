#!/usr/bin/env bash
# Print a Nerd Font icon for the currently active PulseAudio/PipeWire sink.
# Categories: headphones, laptop/internal speakers, external (HDMI/monitor) speakers.

sink=$(pactl get-default-sink 2>/dev/null)
[[ -z "$sink" ]] && exit 0

active_port=$(pactl list sinks 2>/dev/null | awk -v s="$sink" '
  /^Sink #/        { in_sink=0 }
  $1=="Name:" && $2==s { in_sink=1 }
  in_sink && /Active Port:/ { print tolower($3); exit }
')

shopt -s nocasematch
case "$sink$active_port" in
    *bluez*|*headphone*|*headset*|*usb*headphone*)
        icon="󰋋" ;;                       # headphones
    *hdmi*|*displayport*|*dp_*|*iec958*)
        icon="󰽟" ;;                       # monitor / external digital speakers
    *)
        icon="󰌢" ;;                       # laptop / built-in speakers
esac
shopt -u nocasematch

echo "$icon"
