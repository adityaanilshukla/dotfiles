#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

# Port of polybar's [module/audio-sink] (main branch, polybar/audio-sink.sh):
# a single purple glyph naming the category of the current audio output, with
# no label. Three categories, same as polybar: headphones, external/monitor
# speakers, built-in speakers.
#
# Two sources, split by cost, because the obvious one is too slow to poll at
# the rate this needs to feel instant:
#
#   SwitchAudioSource -c     ~20ms, gives the device NAME and nothing else
#   system_profiler          ~130ms, gives the name AND the transport
#
# Transport is what separates a DisplayPort monitor from built-in speakers, so
# it cannot be dropped. But it only matters when the device actually changes,
# and the device changes rarely. So the every-tick path is the cheap one: read
# the name, compare it to the last name seen, and exit having done nothing if
# it matches. The expensive call runs only on an actual switch, which is also
# the only moment the bar needs redrawing.
#
# Net effect at update_freq=1: ~20ms per second steady state, one ~130ms call
# when headphones go in. The old shape was a 130ms call every 5 seconds and a
# glyph that lagged the switch by up to 5.
CACHE="/tmp/sketchybar_audio_sink"

# Two devices in system_profiler can look default. "Default System Output
# Device" takes alert sounds, "Default Output Device" takes application audio,
# and they differ whenever a monitor is attached. The second is the one worth
# showing, so the match is anchored on the full phrase. Device names contain
# spaces, so the two fields come back on separate lines rather than split by
# read.
probe_slow() {
  system_profiler SPAudioDataType 2>/dev/null | awk '
    /^        [^ ].+:$/              { dev = $0; sub(/^ +/, "", dev); sub(/:$/, "", dev) }
    /^ +Default Output Device: Yes$/ { want = dev }
    want != "" && dev == want && /^ +Transport: / { print want; print $2; exit }
  '
}

# Transport carries most of the answer, but not all of it: a USB DAC and a USB
# headset report the same transport, so the device name breaks the tie exactly
# as polybar's port match does. Wired 3.5mm is covered because macOS names that
# device "External Headphones" even though its transport is Built-in.
#
# `earpod` is listed separately from `airpod` on purpose: USB-C EarPods report
# the name "EarPods" with transport USB, which matched neither the name arm nor
# any transport arm and so drew the laptop glyph while they were plugged in.
# The two words differ by a letter and it is an easy one to assume is covered.
#
# Known gap, inherited from the polybar version: USB or wired headphones whose
# name is a bare model number ("WH-1000XM4") match nothing and fall through to
# the laptop glyph. Add the model to the first case arm if that bothers you;
# there is no reliable way to infer it from what CoreAudio reports — nothing
# CoreAudio exposes distinguishes a headset from a speaker, only how it is
# attached, and USB carries both.
classify() {
  local dev="$1" transport="$2" icon
  shopt -s nocasematch
  case "$dev" in
    *headphone*|*earphone*|*headset*|*earpod*|*airpod*|*buds*)
      icon="$SINK_HEADPHONES" ;;
    *)
      case "$transport" in
        Bluetooth*)               icon="$SINK_HEADPHONES" ;;
        DisplayPort|HDMI|AirPlay) icon="$SINK_MONITOR" ;;
        *)                        icon="$SINK_LAPTOP" ;;
      esac
      ;;
  esac
  shopt -u nocasematch
  printf '%s' "$icon"
}

# --- fast path ---
# SwitchAudioSource is the cheap probe. If it is missing (fresh machine, or the
# Brewfile not yet applied) fall back to the slow probe every tick: correct,
# just laggier, which is better than a blank module.
if command -v SwitchAudioSource >/dev/null 2>&1; then
  CURRENT=$(SwitchAudioSource -c 2>/dev/null)
else
  CURRENT=$(probe_slow | sed -n 1p)
fi

if [ -z "$CURRENT" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Unchanged since the last tick: the glyph on screen is already right, so do
# not spend a system_profiler call or an IPC round trip to redraw it.
#
# The cache lives in /tmp and therefore outlives a `sketchybar --reload`, which
# rebuilds every item from scratch with no icon. A stale hit there would leave
# the module permanently blank until the next device change, so sketchybarrc
# deletes this file before it adds the item.
if [ -f "$CACHE" ]; then
  IFS=$'\t' read -r CACHED_DEV CACHED_ICON < "$CACHE"
  if [ "$CURRENT" = "$CACHED_DEV" ] && [ -n "$CACHED_ICON" ]; then
    exit 0
  fi
fi

# --- slow path, only on an actual device change ---
INFO=$(probe_slow)
SINK_DEV=$(printf '%s\n' "$INFO" | sed -n 1p)
TRANSPORT=$(printf '%s\n' "$INFO" | sed -n 2p)

# Nothing reported a default output: no audio hardware the bar can describe, so
# say nothing rather than guess. Requires updates=on to recover.
if [ -z "$SINK_DEV" ] && [ -z "$TRANSPORT" ]; then
  rm -f "$CACHE"
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

ICON=$(classify "$SINK_DEV" "$TRANSPORT")
printf '%s\t%s' "$SINK_DEV" "$ICON" >"$CACHE"

sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$PURPLE" label=""
