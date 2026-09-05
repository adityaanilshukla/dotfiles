#!/usr/bin/env bash
#
# Register the Claude Code notification hooks in ~/.claude/settings.json.
#
# Its own module for the same reason karabiner is: settings.json cannot be
# symlinked. Claude Code writes to it (theme changes, onboarding state, and
# whatever future keys it adds), so a symlink into this repo would mean the app
# editing tracked files under you and every session showing up as a diff. The
# hook entries are merged into whatever is already there instead.
#
# Idempotent by REPLACEMENT, not by append. That distinction is the whole point
# of this script: on the machine these hooks came from, settings.json had the
# same hook registered two and three times over, so every Stop fired two
# banners and two overlapping sounds. Appending is how that happens. This
# strips every entry pointing at notify.sh first, then adds exactly one back.
#
# Read-only on failure: nothing is written unless the new JSON parses.

set -euo pipefail

SETTINGS="${HOME}/.claude/settings.json"
HOOK="${HOME}/.claude/hooks/notify.sh"

command -v jq >/dev/null 2>&1 || { echo "  jq not found — settings.json not touched."; exit 1; }

# The symlink is made by the main install.sh. If it is not there yet, wiring
# settings.json to point at it would register a hook that fails on every event.
if [[ ! -x "$HOOK" ]]; then
  echo "  $HOOK missing or not executable — hooks not registered."
  exit 1
fi

mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

# A settings.json that is already corrupt would otherwise be silently replaced
# by whatever jq makes of it.
if ! jq empty "$SETTINGS" 2>/dev/null; then
  echo "  $SETTINGS is not valid JSON — refusing to touch it."
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# `$HOME` is written literally into the file, not expanded. Claude Code expands
# it when running the command, and leaving it unexpanded keeps settings.json
# portable between machines and users.
jq '
  def ours: (.hooks // []) | any(.command // "" | contains("/.claude/hooks/notify.sh"));
  def prune($k): (.hooks[$k] // []) | map(select(ours | not));
  def entry($ev): { hooks: [ { type: "command",
                               command: ("$HOME/.claude/hooks/notify.sh " + $ev),
                               timeout: 5 } ] };

  .hooks //= {}
  | .hooks.Notification = (prune("Notification") + [entry("Notification")])
  | .hooks.Stop         = (prune("Stop")         + [entry("Stop")])
' "$SETTINGS" > "$tmp"

# Prove the result before overwriting. jq exiting 0 on a truncated write is
# rarer than a full disk but not impossible, and this file is the app's config.
if ! jq empty "$tmp" 2>/dev/null || [[ ! -s "$tmp" ]]; then
  echo "  merge produced invalid JSON — $SETTINGS left unchanged."
  exit 1
fi

# Only back up when something actually changes, so re-running does not bury the
# last genuinely different version under identical copies.
if cmp -s "$SETTINGS" "$tmp"; then
  echo "  Claude hooks already registered."
  exit 0
fi

cp "$SETTINGS" "${SETTINGS}.bak"
cat "$tmp" > "$SETTINGS"   # cat, not mv: keeps the original mode and ownership
echo "  Claude notification hooks registered (backup: ${SETTINGS}.bak)"
