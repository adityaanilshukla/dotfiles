#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

# Port of polybar's [module/audio-sink] (main branch, polybar/audio-sink.sh):
# a single purple glyph naming the category of the current audio output, with
# no label. Three categories, same as polybar: headphones, external/monitor
# speakers, built-in speakers.
#
# The Linux version reads `pactl get-default-sink` and the sink's Active Port.
# macOS has no pactl, and no cheap CoreAudio CLI is installed, so the source
# here is `system_profiler SPAudioDataType`. It costs about 0.08s of CPU per
# call, against a few milliseconds for pactl, which is why the item polls at
# 5s rather than polybar's 2s. Output devices change on the scale of plugging
# in headphones, so the extra latency is not noticeable; drop it back to 2 in
# sketchybarrc if you disagree.
#
# Two devices can both look default. "Default System Output Device" is where
# alert sounds go, "Default Output Device" is where application audio goes,
# and they differ whenever a monitor is attached. The latter is the one worth
# showing, so the match is anchored on the full phrase.
# Device names contain spaces, so the two fields come back on separate lines
# rather than split by read.
INFO_OUT=$(system_profiler SPAudioDataType 2>/dev/null | awk '
  /^        [^ ].+:$/          { dev = $0; sub(/^ +/, "", dev); sub(/:$/, "", dev) }
  /^ +Default Output Device: Yes$/ { want = dev }
  want != "" && dev == want && /^ +Transport: / { print want; print $2; exit }
')
SINK_NAME=$(printf '%s\n' "$INFO_OUT" | sed -n 1p)
TRANSPORT=$(printf '%s\n' "$INFO_OUT" | sed -n 2p)

# Nothing reported a default output: no audio hardware the bar can describe,
# so say nothing rather than guess. Requires updates=on to recover.
if [ -z "$TRANSPORT" ] && [ -z "$SINK_NAME" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Transport carries most of the answer, but not all of it: a USB DAC and a USB
# headset report the same transport, so the device name breaks the tie exactly
# as polybar's port match does. Wired 3.5mm headphones are covered because
# macOS names that device "External Headphones" even though its transport is
# Built-in.
#
# Known gap, inherited from the polybar version: USB or wired headphones whose
# name is a bare model number ("WH-1000XM4") match nothing and fall through to
# the laptop glyph. Add the model to the first case arm if that bothers you;
# there is no reliable way to infer it from what CoreAudio reports.
shopt -s nocasematch
case "$SINK_NAME" in
  *headphone*|*headset*|*airpod*|*buds*)
    ICON="$SINK_HEADPHONES" ;;
  *)
    case "$TRANSPORT" in
      Bluetooth*)              ICON="$SINK_HEADPHONES" ;;
      DisplayPort|HDMI|AirPlay) ICON="$SINK_MONITOR" ;;
      *)                       ICON="$SINK_LAPTOP" ;;
    esac
    ;;
esac
shopt -u nocasematch

sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$PURPLE" label=""
