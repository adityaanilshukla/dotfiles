#!/bin/sh
# Desktop notifications that identify WHICH Claude Code session is talking.
#
#   ~/.claude/hooks/notify.sh Notification   < hook JSON on stdin
#   ~/.claude/hooks/notify.sh Stop           < hook JSON on stdin
#
# Label format: <dir>@<branch> · <session prefix>   e.g. "api@fix-auth · a3f9c1"
#
# Uses osascript rather than terminal-notifier. On macOS 26 the Homebrew
# terminal-notifier bundle is ad-hoc/linker-signed with a broken signature, so
# macOS never creates a notification permission entry for it: its notifications
# are accepted and filed into Notification Center (visible via
# `terminal-notifier -list ALL`) but never rendered as banners. Re-signing and
# re-registering with lsregister does not fix it. osascript posts through an
# already-authorised host app and displays correctly.
#
# Tradeoff: osascript has no equivalent of terminal-notifier's -group, so a
# session's banners stack instead of replacing one another. The session label
# in the title is what distinguishes sessions, and that is unaffected.
#
# Always exits 0: a notifier problem must never block or fail the session.

# Sound, and how loud relative to current system volume. 1.0 is unattenuated.
SOUND_FILE="/System/Library/Sounds/Bottle.aiff"
SOUND_VOLUME="0.5"

event="${1:-Notification}"
input="$(cat 2>/dev/null)"

command -v jq >/dev/null 2>&1 || exit 0
command -v osascript >/dev/null 2>&1 || exit 0

field() {
  printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null
}

cwd="$(field '.cwd')"
session_id="$(field '.session_id')"
message="$(field '.message')"

# Every field below tolerates being absent or empty.
[ -n "$cwd" ] || cwd="$PWD"
base="$(basename "$cwd" 2>/dev/null)"
[ -n "$base" ] || base="claude"

# Branch is decoration: a non-repo cwd just yields no @branch segment.
branch="$(git --no-optional-locks -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ -n "$branch" ] && base="${base}@${branch}"

prefix="$(printf '%s' "$session_id" | cut -c1-6)"
[ -n "$prefix" ] || prefix="nosess"

label="${base} · ${prefix}"

case "$event" in
  Stop)
    title="✅ ${label}"
    body="Done"
    ;;
  *)
    title="🔔 ${label}"
    body="${message:-Needs your input}"
    ;;
esac

# Values are passed as argv, never interpolated into the script text. A message
# containing quotes or backslashes would otherwise produce a syntax error or,
# worse, be parsed as AppleScript.
#
# Deliberately posted WITHOUT `sound name`: AppleScript always plays that at
# full alert volume with no way to attenuate it. The sound is played separately
# below so its level can be controlled.
osascript \
  -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title (item 2 of argv)' \
  -e 'end run' \
  "$body" "$title" >/dev/null 2>&1

# afplay -v scales amplitude relative to the current system output volume, so
# this stays at half of wherever the system is set rather than a fixed level.
# Detached so a half-second sound never delays the hook returning.
if [ -r "$SOUND_FILE" ] && command -v afplay >/dev/null 2>&1; then
  ( afplay -v "$SOUND_VOLUME" "$SOUND_FILE" >/dev/null 2>&1 & ) &
fi

exit 0
