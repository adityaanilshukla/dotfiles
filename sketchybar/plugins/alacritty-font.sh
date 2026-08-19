#!/usr/bin/env bash

# Nothing to draw. This item exists only so that sketchybar's display_change
# event has somewhere to land: it is the one thing already running on this
# machine that knows when a monitor is plugged in or unplugged, so using it
# saves adding a launchd agent or a polling loop for the same signal.
#
# All the logic is in scripts/alacritty-font-size, which is also runnable by
# hand. Called by absolute path because sketchybar runs under launchd with
# PATH=/usr/bin:/bin, so ~/.local/bin is not searched.
exec "$HOME/.local/bin/alacritty-font-size"
