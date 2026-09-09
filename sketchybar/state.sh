#!/usr/bin/env bash
#
# Where the bar keeps its scratch state. One definition, because three plugins
# and `scripts/t` all need to agree on these paths and until now each one
# spelled them out for itself -- the same decision made four times, in four
# files, with nothing keeping them in step.
#
# ${TMPDIR:-/tmp} rather than a bare /tmp. On macOS TMPDIR is a per-user
# directory (/var/folders/.../T/) with mode 700, so nothing another account can
# create first. /tmp is world-writable, which meant another user on the machine
# could have squatted /tmp/sketchybar_timer.state and had this read theirs.
#
# The fallback matters only in the case where TMPDIR is genuinely unset, which
# is not the case here: sketchybar runs from ~/Library/LaunchAgents, so it is a
# user agent and gets the same TMPDIR as a login shell. Verified rather than
# assumed -- a probe script run from inside sketchybar and an interactive shell
# both reported /var/folders/7y/6tgd.../T/ and uid 501.
#
# Consequence worth knowing: a running timer is keyed by file path, so changing
# this line orphans one that is already counting down. Harmless -- it just
# stops being drawn -- but `t` has to be re-run.

: "${SKETCHYBAR_STATE_DIR:=${TMPDIR:-/tmp}}"
SKETCHYBAR_STATE_DIR="${SKETCHYBAR_STATE_DIR%/}"

# Shared with scripts/t, which writes it and lets the plugin render it.
export SKETCHYBAR_TIMER_STATE="$SKETCHYBAR_STATE_DIR/sketchybar_timer.state"

# Last audio device seen, so the every-tick path can skip a system_profiler
# call. sketchybarrc deletes this at startup; see the note there.
export SKETCHYBAR_AUDIO_SINK_CACHE="$SKETCHYBAR_STATE_DIR/sketchybar_audio_sink"

# Which display currently carries DDC audio, so the steady-state volume poll is
# one BetterDisplay query instead of enumerating every display.
export SKETCHYBAR_DDC_SPEAKER_CACHE="$SKETCHYBAR_STATE_DIR/sketchybar_ddc_speaker"
