#!/usr/bin/env bash

# Nerd Font glyph codepoints, rendered in Hack Nerd Font. Built from UTF-8 hex
# bytes so the source stays pure ASCII and survives any editor or transport
# that mangles private-use-area characters.
#
# These match polybar's glyphs on the main branch, so the two bars show the
# same symbols. Where a name says (md) the glyph is Material Design, which
# lives above U+FFFF; all of them are present in Hack Nerd Font 3.5.0, checked
# via Core Text rather than assumed.

# Battery: nf-md-battery_charging (U+F0084), nf-md-battery (U+F0079).
# polybar distinguishes charging from discharging, not charge level, so there
# is deliberately no 5-step ramp here.
export BATTERY_CHARGING=$(printf '\xf3\xb0\x82\x84')
export BATTERY=$(printf '\xf3\xb0\x81\xb9')

# Volume: nf-md-volume_high (U+F057E). polybar shows one icon at any level and
# drops to a bare "muted" label when muted, so there is no per-level ramp.
# Named _ICON because volume.sh uses $VOLUME for the percentage itself.
export VOLUME_ICON=$(printf '\xf3\xb0\x95\xbe')

# Network: nf-md-wifi_strength_4 (U+F0928), nf-oct-server (U+EF44) for wired.
# polybar hides the module entirely when the interface is down, so there is no
# "disconnected" glyph.
export WIFI=$(printf '\xf3\xb0\xa4\xa8')
export ETHERNET=$(printf '\xee\xbd\x84')

# Audio sink, for the module ported from polybar/audio-sink.sh:
# nf-md-headphones (U+F02CB), nf-md-monitor_speaker (U+F0F5F),
# nf-md-laptop (U+F0322).
export SINK_HEADPHONES=$(printf '\xf3\xb0\x8b\x8b')
export SINK_MONITOR=$(printf '\xf3\xb0\xbd\x9f')
export SINK_LAPTOP=$(printf '\xf3\xb0\x8c\xa2')

# Date: nf-fa-calendar (U+F073). polybar's date module uses the calendar
# glyph, not a clock face.
export CALENDAR=$(printf '\xef\x81\xb3')

# Power menu: nf-fa-power_off (U+F011), nf-fa-angle_right (U+F105).
export POWER=$(printf '\xef\x80\x91')
export ANGLE_RIGHT=$(printf '\xef\x84\x85')

# Timer: nf-fa-hourglass_start/half/end (U+F251/F252/F253), nf-fa-coffee
# (U+F0F4) for break. These already matched polybar and are unchanged.
export HOURGLASS_START=$(printf '\xef\x89\x91')
export HOURGLASS_HALF=$(printf '\xef\x89\x92')
export HOURGLASS_END=$(printf '\xef\x89\x93')
export COFFEE=$(printf '\xef\x83\xb4')

# Timer paused: nf-fa-play (U+F04B). Shows the action a `t play` will take
# next, same convention as a media player's play/pause button.
export PLAY=$(printf '\xef\x81\x8b')
