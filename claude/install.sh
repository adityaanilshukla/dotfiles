#!/usr/bin/env bash
#
# Register the Claude Code hooks and permission rules in ~/.claude/settings.json.
#
# Two unrelated things live here because they share the same merge problem:
# the notification hooks (banner + sound on Stop/Notification), and the sudo
# guard (a PreToolUse hook plus matching deny rules).
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
NOSUDO="${HOME}/.claude/hooks/no-sudo.sh"

command -v jq >/dev/null 2>&1 || { echo "  jq not found — settings.json not touched."; exit 1; }

# The symlinks are made by the main install.sh. If they are not there yet,
# wiring settings.json to point at them would register hooks that fail on
# every event.
for h in "$HOOK" "$NOSUDO"; do
  if [[ ! -x "$h" ]]; then
    echo "  $h missing or not executable — hooks not registered."
    exit 1
  fi
done

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
# The deny rules and the PreToolUse hook are two layers of the same guard.
# A deny rule only matches the start of a command, so it stops `sudo ...` and
# nothing else; the hook reads the whole string and also catches `x; sudo y`
# and osascript's "with administrator privileges". Rules are cheap and run
# first, so both are worth having.
jq '
  def ours($f): (.hooks // []) | any(.command // "" | contains($f));
  def prune($k; $f): (.hooks[$k] // []) | map(select(ours($f) | not));
  def notify($ev): { hooks: [ { type: "command",
                                command: ("$HOME/.claude/hooks/notify.sh " + $ev),
                                timeout: 5 } ] };

  ["Bash(sudo:*)", "Bash(sudo *)", "Bash(doas:*)", "Bash(doas *)"] as $denies
  | .hooks //= {}
  | .hooks.Notification = (prune("Notification"; "/notify.sh") + [notify("Notification")])
  | .hooks.Stop         = (prune("Stop";         "/notify.sh") + [notify("Stop")])
  | .hooks.PreToolUse   = (prune("PreToolUse";   "/no-sudo.sh") + [
      { matcher: "Bash",
        hooks: [ { type: "command",
                   command: "$HOME/.claude/hooks/no-sudo.sh",
                   timeout: 5 } ] } ])
  | .permissions //= {}
  | .permissions.deny = (((.permissions.deny // []) - $denies) + $denies)
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
  echo "  Claude hooks and deny rules already registered."
  exit 0
fi

cp "$SETTINGS" "${SETTINGS}.bak"
cat "$tmp" > "$SETTINGS"   # cat, not mv: keeps the original mode and ownership
echo "  Claude hooks and sudo deny rules registered (backup: ${SETTINGS}.bak)"
