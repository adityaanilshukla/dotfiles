#!/usr/bin/env bash

# Palette, kept in sync with polybar's [colors] block on the main branch and
# with alacritty.toml. These are the same hexes, so the bar matches the
# terminal on both machines rather than drifting into a second theme.
#
# sketchybar wants 0xAARRGGBB; polybar wants #RRGGBB. Both spellings are here
# so the mapping stays obvious when diffing the two configs side by side.

# ----- polybar's named colors -----
export BACKGROUND=0xff161718   # #161718
export FOREGROUND=0xffc4c8c5   # #c4c8c5
export ALERT=0xfffc5ef0        # #fc5ef0
export SUCCESS=0xff86c38a      # #86c38a
export WARNING=0xffffd6b1      # #ffd6b1
export BLUE_BRIGHT=0xff4da3ff  # #4da3ff  polybar "blue"
export BLUE_DEEP=0xff1a5fb4    # #1a5fb4  polybar "blue-deep", active workspace
export PURPLE=0xffb9b5fc       # #b9b5fc
export AQUA=0xff85befd         # #85befd
export DISABLED=0xff6f7377     # #6f7377
export PLAIN_WHITE=0xffdfdfdf  # #dfdfdf

# ----- names the plugins already use, mapped onto the palette above -----
# Kept so the plugin scripts don't all need rewriting, and so a future module
# ported from polybar can use either vocabulary.
export WHITE=$PLAIN_WHITE
export BLACK=$BACKGROUND
export RED=$ALERT
export GREEN=$SUCCESS
export BLUE=$BLUE_BRIGHT
export YELLOW=$WARNING
export ORANGE=$WARNING       # polybar has no separate orange tier
export MAGENTA=$PURPLE
export GREY=$DISABLED
export TRANSPARENT=0x00000000

# Bar stays pure black rather than $BACKGROUND on purpose: at height 37 it
# matches the MacBook notch, so the notch disappears into the bar when
# undocked. #161718 would outline it. Everything else follows polybar.
export BAR_COLOR=0xff000000
export ITEM_BG_COLOR=$BACKGROUND
export ACCENT_COLOR=$BLUE_DEEP
