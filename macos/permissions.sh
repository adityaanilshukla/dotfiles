#!/usr/bin/env bash
#
# One job: report which macOS permissions this setup needs granted by hand, and
# walk you to the exact System Settings pane for the ones that are missing.
#
# Nothing here can GRANT a permission. TCC (the permissions database) is
# SIP-protected precisely so that a script cannot approve itself for
# Accessibility. So the job is: detect what can be detected, say plainly what
# cannot, explain what breaks without each one, and open the right pane.
#
# Two modes, and the difference matters:
#   (no args)  print the checklist and exit. NEVER blocks, never prompts, so
#              install.sh can call it without the install ever hanging.
#   --walk     the interactive pass. Opens each pane, waits for you.
#
# Panes are grouped by SETTINGS PANE, not by app: four apps need Accessibility,
# and that is one visit rather than four interruptions.
#
# Re-running is the point. This doubles as a doctor command - run it in six
# months to find what got revoked, without re-running the installer.
set -euo pipefail

# --- Presentation ---------------------------------------------------------
# Standard ANSI codes rather than hex, so the output inherits whatever palette
# the terminal already uses instead of fighting it. Disabled when stdout is not
# a terminal (piping to a file should not embed escape codes) and when NO_COLOR
# is set, which is the cross-tool convention for "I do not want colour".
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; OFF=$'\e[0m'
  RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'
else
  BOLD=''; DIM=''; OFF=''; RED=''; GREEN=''; YELLOW=''; BLUE=''
fi

MARK_OK="${GREEN}✓${OFF}"
MARK_NO="${RED}✗${OFF}"
MARK_UNKNOWN="${YELLOW}?${OFF}"
MARK_TRUST="${DIM}·${OFF}"

RULE="──────────────────────────────────────────────────────────────"

heading() { printf '\n%s%s%s\n %s%s  %s%s\n%s%s%s\n\n' \
  "$DIM" "$RULE" "$OFF" "$BOLD$BLUE" "$1" "$2" "$OFF" "$DIM" "$RULE" "$OFF"; }

# --- The table ------------------------------------------------------------
# id|Human name|full System Settings URL. Stored as the whole URL rather than
# an anchor appended to a shared prefix, because not every pane worth checking
# lives under Privacy & Security -- Login Items & Extensions is its own
# settings extension with an unrelated URL.
PANES=(
  "accessibility|Accessibility|x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  "input|Input Monitoring|x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
  "fulldisk|Full Disk Access|x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
)

# Apps needing each pane, as "App name<TAB>what breaks without it". The reason
# is not padding: "AeroSpace needs Accessibility" is forgettable at 1am on a
# fresh machine, "no tiling at all without it" is not.
apps_for() {
  case "$1" in
    accessibility)
      printf 'AeroSpace\tno tiling at all without it\n'
      printf 'Karabiner-Elements\tno key remaps, no push-to-talk\n'
      printf 'BetterDisplay\tno external display brightness\n'
      printf 'Raycast\talt-space does nothing\n'
      ;;
    input)
      printf 'Karabiner-Elements\tcannot read the keyboard to remap it\n'
      ;;
    fulldisk)
      printf 'Alacritty\tneeded for: sudo systemsetup -setremotelogin on\n'
      ;;
  esac
}

# --- Probes ---------------------------------------------------------------
# Each returns: 0 granted, 1 denied, 2 undetectable. Never guess a 0 - a
# checklist that invents a tick is worse than one that admits ignorance.

probe_accessibility() {
  # AeroSpace genuinely cannot enumerate windows without Accessibility, so a
  # successful query is proof rather than inference.
  command -v aerospace >/dev/null 2>&1 || return 2
  aerospace list-windows --all >/dev/null 2>&1 && return 0 || return 1
}

probe_input() {
  # Karabiner's virtual keyboard daemon only stays up once Input Monitoring is
  # granted. Indicative, not proof, so a failure reports as undetectable.
  pgrep -f 'Karabiner-VirtualHIDDevice-Daemon' >/dev/null 2>&1 && return 0
  return 2
}

probe_fulldisk() {
  # Reading the TCC database is itself gated behind Full Disk Access, which
  # makes it an exact test of the thing we are asking about.
  sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
    'select 1' >/dev/null 2>&1 && return 0 || return 1
}

probe() { "probe_$1"; }

# --- Rendering ------------------------------------------------------------
status_mark() {
  case "$1" in
    0) printf '%s' "$MARK_OK" ;;
    1) printf '%s' "$MARK_NO" ;;
    *) printf '%s' "$MARK_UNKNOWN" ;;
  esac
}

status_note() {
  case "$1" in
    0) printf '%sgranted%s' "$DIM" "$OFF" ;;
    1) printf '%s%s missing%s' "$RED" "$2" "$OFF" ;;
    *) printf '%scannot detect — will ask%s' "$YELLOW" "$OFF" ;;
  esac
}

summarise() {
  local pending=0 entry id name rc count
  printf '\n%sProbing what is already granted...%s\n\n' "$BOLD" "$OFF"
  for entry in "${PANES[@]}"; do
    IFS='|' read -r id name _ <<<"$entry"
    rc=0; probe "$id" || rc=$?
    count=$(apps_for "$id" | wc -l | tr -d ' ')
    printf '  %s  %-20s %s\n' "$(status_mark "$rc")" "$name" "$(status_note "$rc" "$count app(s)")"
    [[ $rc -eq 0 ]] || pending=$((pending + 1))
  done
  printf '\n'
  return "$pending"
}

# --- Walk -----------------------------------------------------------------
open_pane() {
  open "$1" 2>/dev/null || true
}

walk_pane() {
  local id="$1" name="$2" anchor="$3" position="$4" total="$5" app why
  heading "$position of $total" "$name"
  printf '  %sTick these:%s\n\n' "$BOLD" "$OFF"
  while IFS=$'\t' read -r app why; do
    printf '    %s%-22s%s %s%s%s\n' "$BOLD" "$app" "$OFF" "$DIM" "$why" "$OFF"
  done < <(apps_for "$id")
  printf '\n  %sPane is open. If an app is not listed, click + — they are all\n  in /Applications.%s\n\n' "$DIM" "$OFF"
  open_pane "$anchor"
  printf '    %s[enter]%s done    %s[s]%s skip    %s[q]%s quit  ' \
    "$GREEN" "$OFF" "$YELLOW" "$OFF" "$RED" "$OFF"
}

verify_pane() {
  local id="$1" rc=0
  probe "$id" || rc=$?
  printf '\n  %sVerifying...%s\n' "$BOLD" "$OFF"
  case "$rc" in
    0) printf '    %s  confirmed by probe\n' "$MARK_OK" ;;
    1) printf '    %s  still not detected — re-run to check again\n' "$MARK_NO" ;;
    *) printf '    %s  cannot verify — taking your word\n' "$MARK_TRUST" ;;
  esac
}

walk() {
  local todo=() entry id name anchor rc i=0 total answer
  for entry in "${PANES[@]}"; do
    IFS='|' read -r id _ _ <<<"$entry"
    rc=0; probe "$id" || rc=$?
    [[ $rc -eq 0 ]] || todo+=("$entry")
  done
  total=${#todo[@]}
  if [[ $total -eq 0 ]]; then
    printf '%sNothing to do — everything detectable is granted.%s\n\n' "$GREEN" "$OFF"
    return 0
  fi
  printf '%s%d pane(s) to visit.%s %sCtrl-C any time — re-running picks up where you left off.%s\n' \
    "$BOLD" "$total" "$OFF" "$DIM" "$OFF"
  for entry in "${todo[@]}"; do
    i=$((i + 1))
    IFS='|' read -r id name anchor <<<"$entry"
    walk_pane "$id" "$name" "$anchor" "$i" "$total"
    # Read from the terminal rather than stdin so this still works when the
    # script is piped. If there is no terminal at all (CI, a pipeline), treat
    # it as quit rather than spilling a shell error and looping forever.
    # stderr is redirected BEFORE stdin on purpose: redirections are applied
    # left to right, so a failing </dev/tty would print its error before a
    # trailing 2>/dev/null could suppress it.
    read -r answer 2>/dev/null </dev/tty || answer=q
    case "$answer" in
      q|Q) printf '\n%sStopped. Re-run when ready.%s\n\n' "$YELLOW" "$OFF"; return 0 ;;
      s|S) printf '\n  %sskipped%s\n' "$DIM" "$OFF" ;;
      *)   verify_pane "$id" ;;
    esac
  done
  printf '\n'
  heading "Summary" ""
  summarise || true
}

# --- Main -----------------------------------------------------------------
main() {
  case "${1:-}" in
    --walk) walk ;;
    '')
      local pending=0
      summarise || pending=$?
      if [[ $pending -gt 0 ]]; then
        printf '%s%d item(s) need attention.%s  Run:  %s%s --walk%s\n\n' \
          "$BOLD$YELLOW" "$pending" "$OFF" "$BOLD" "$0" "$OFF"
      else
        printf '%sAll detectable permissions are granted.%s\n\n' "$GREEN" "$OFF"
      fi
      ;;
    *)
      printf 'usage: %s [--walk]\n' "$0" >&2
      return 2
      ;;
  esac
}

main "$@"
