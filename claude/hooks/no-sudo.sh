#!/usr/bin/env bash
#
# PreToolUse/Bash hook: refuse privilege escalation from inside a session.
#
# Why a hook and not just a permission rule: permission rules match the START of
# a command, so `Bash(sudo:*)` catches `sudo pmset ...` and nothing else. It
# does not catch `true; sudo x`, it does not catch `/usr/bin/sudo`, and most of
# all it does not catch
#
#   osascript -e 'do shell script "pmset -c sleep 0" with administrator privileges'
#
# which is a completely different binary and routes the authorisation through
# macOS's own GUI dialog instead of a TTY. That is the hole this closes: the
# deny rules in settings.json handle the plain case cheaply, and this handles
# the rest by looking at the whole command string.
#
# THIS IS A GUARDRAIL, NOT A SANDBOX. It reads the literal text of the command.
# Anything that hides the word -- base64, a variable holding "sudo", a script on
# disk that escalates internally -- goes straight through. It exists to stop an
# escalation being reached for casually or by habit, not to contain one that is
# actively trying to get out. Do not treat a passing command as proof it cannot
# gain root.
#
# Matching is deliberately at COMMAND POSITION only (start of string, or after
# ; | & ( ` or a newline). Matching a bare " sudo " anywhere would also fire on
# prose that merely mentions it, and writing documentation about sudo is a
# normal thing to do -- including in this repo.
#
# Exit 0 always. A hook that dies must not take the tool call down with it; the
# decision is carried in the JSON on stdout, and no JSON means "no opinion".

command="$(jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
[[ -n "$command" ]] || exit 0

deny() {
  jq -cn --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Command position: start, or after a separator that begins a new command.
AT_START='(^|[;&|(`]|\$\()[[:space:]]*'

if printf '%s' "$command" | grep -qE "${AT_START}(/usr/bin/|/bin/)?sudo([[:space:]]|$)"; then
  deny "sudo is disabled in this session. Ask the user to run it themselves in a terminal."
fi

if printf '%s' "$command" | grep -qE "${AT_START}doas([[:space:]]|$)"; then
  deny "doas is disabled in this session. Ask the user to run it themselves in a terminal."
fi

# The osascript route. No command-position anchor: this phrase only ever means
# one thing, and it can sit anywhere inside the -e argument.
if printf '%s' "$command" | grep -qiE 'with[[:space:]]+administrator[[:space:]]+privileges'; then
  deny "Escalating via 'with administrator privileges' is disabled in this session. Ask the user to run it themselves in a terminal."
fi

exit 0
