#!/usr/bin/env bash

# Nerd Font glyph codepoints (Font Awesome range) — rendered in Hack Nerd Font.
# Built from UTF-8 hex bytes so the source stays pure ASCII and survives any
# editor or transport that mangles private-use-area characters.

# Battery: nf-fa-battery_4..0 (U+F240..F244), nf-fa-bolt (U+F0E7) for charging
export BATTERY_100=$(printf '\xef\x89\x80')
export BATTERY_75=$(printf '\xef\x89\x81')
export BATTERY_50=$(printf '\xef\x89\x82')
export BATTERY_25=$(printf '\xef\x89\x83')
export BATTERY_0=$(printf '\xef\x89\x84')
export BATTERY_CHARGING=$(printf '\xef\x83\xa7')

# Volume: nf-fa-volume_up/down/off (U+F028, F027, F026)
export VOLUME_100=$(printf '\xef\x80\xa8')
export VOLUME_66=$(printf '\xef\x80\xa7')
export VOLUME_33=$(printf '\xef\x80\xa7')
export VOLUME_10=$(printf '\xef\x80\xa7')
export VOLUME_0=$(printf '\xef\x80\xa6')

# Wifi: nf-fa-wifi (U+F1EB), nf-fa-times (U+F00D) for disconnected
export WIFI_CONNECTED=$(printf '\xef\x87\xab')
export WIFI_DISCONNECTED=$(printf '\xef\x80\x8d')

# Other: nf-fa-clock_o (U+F017), nf-fa-calendar (U+F073), nf-fa-apple (U+F179)
export CLOCK=$(printf '\xef\x80\x97')
export CALENDAR=$(printf '\xef\x81\xb3')
export APPLE=$(printf '\xef\x85\xb9')

# Timer: nf-fa-hourglass_start/half/end (U+F251/F252/F253), nf-fa-coffee (U+F0F4) for break
export HOURGLASS_START=$(printf '\xef\x89\x91')
export HOURGLASS_HALF=$(printf '\xef\x89\x92')
export HOURGLASS_END=$(printf '\xef\x89\x93')
export COFFEE=$(printf '\xef\x83\xb4')

# Timer paused: nf-fa-play (U+F04B) — shows the action a `t pause` toggle
# will take next (resume), same convention as a media player's play/pause button.
export PLAY=$(printf '\xef\x81\x8b')
