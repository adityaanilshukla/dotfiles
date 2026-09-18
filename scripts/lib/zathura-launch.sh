#!/usr/bin/env bash
#
# The half of a zathura launch that has nothing to do with syncing.
#
# scripts/library (synced, via online-zathura) and scripts/zp (private, against
# a throwaway data dir) are deliberately two commands and should stay two: one
# records your page in Turso and one must not. But everything AFTER the launch
# -- noticing that zathura came up empty, saying why, and handing it the
# keyboard under AeroSpace -- is the same job, and it was copy-pasted.
#
# It had already drifted. The two copies of the watch loop grew different
# AeroSpace handling, and library carried a comment reasoning about `pipefail`
# in a file that has never set it. That is the cost this file exists to stop:
# a focus bug fixed in one launcher and left standing in the other.
#
# Sourced, never executed. The shebang is there so shellcheck knows the
# dialect; the file is not marked executable.
#
# Everything here is prefixed zathura_ because it lands in the caller's global
# namespace.

# --- window identity --------------------------------------------------------
# zathura has no app bundle id on macOS, so AeroSpace can only be asked about
# it by app-name.
zathura_ids() {
  aerospace list-windows --all --format '%{window-id}|%{app-name}' 2>/dev/null \
    | awk -F'|' '$2 == "zathura" { print $1 }'
}

zathura_have_aerospace() { command -v aerospace >/dev/null 2>&1; }

# Highest zathura window-id currently open, or 0. AeroSpace hands these out in
# increasing order, so anything larger afterwards is the window we just opened.
# Call this BEFORE launching, or there is nothing to compare against.
zathura_max_id() {
  local m
  m="$(zathura_ids | sort -n | tail -n1)"
  printf '%s\n' "${m:-0}"
}

# --- the launch log ---------------------------------------------------------
# One shared path on purpose: only the most recent launch is ever interesting,
# and both commands answer the same question with it.
#
# The log exists because zathura does NOT exit when it cannot read a document.
# It leaves an empty window up and keeps running, so there is no exit code, no
# missing window, and nothing for the watch loop to notice -- what it writes to
# stderr is the only evidence. Discarding that is what once turned a plugin
# rebuild into a debugging session: mupdf printed the exact diagnosis and it
# went to /dev/null.
zathura_log_init() {
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/library"
  mkdir -p "$dir"
  : > "$dir/last-launch.log"
  printf '%s\n' "$dir/last-launch.log"
}

# One `error:` line is printed on every healthy launch of the brew build and
# means nothing: both of its plugins register application/pdf and the second
# registration loses. The GTK4 build ships only mupdf and never prints it, but
# the filter stays because either binary can be the one that runs.
#
# Anything else on an `error:` line is real -- including the ABI complaint
# ("Could not find 'zathura_plugin_8_9'"), which means the plugin directory and
# the binary have got out of step.
zathura_launch_error() {
  grep '^error:' "$1" 2>/dev/null \
    | grep -v 'filetype already registered' \
    | head -n1
}

# What to show once something HAS gone wrong. The line naming the cause is
# often not the `error:` line at all: a mupdf version mismatch reports "cannot
# create context: incompatible header (1.28.2) and library (1.28.3) versions"
# with no prefix, and the `error:` line under it says only "could not open
# document". So print everything zathura wrote apart from the routine noise.
zathura_launch_detail() {
  grep -v -e 'filetype already registered' \
          -e 'Gtk-CRITICAL' \
          -e 'ApplePersistence' \
          "$1" 2>/dev/null | sed '/^[[:space:]]*$/d'
}

# --- watch, and focus -------------------------------------------------------
# zathura_watch <prog> <log> <before-max-id> [linger-seconds]
#
# Returns 0 once the window is up and settled, 1 if the document failed to open
# (the caller decides what that means for its exit status).
#
# One loop does both jobs because the two outcomes arrive in a FIXED ORDER:
# zathura creates its window first and only then parses the document, so a
# failed open lands after the window already exists. Breaking out as soon as
# the window appears would step over the error every time. Focus it, then keep
# watching for a further second.
#
# Runs with or without AeroSpace: reporting a failed open matters on any
# machine, only the focus call is conditional. With no AeroSpace there is
# nothing to focus, so it starts already "focused" -- that drops it straight
# into the grace-period branch and it gives up after a second rather than
# holding the shell for the full five.
#
# linger-seconds is for a caller whose terminal is about to close underneath
# the error message. library runs in an alacritty window that exits with it and
# passes 8; zp runs in your shell, where the message simply stays, and passes
# nothing.
zathura_watch() {
  local prog="$1" log="$2" before_max="$3" linger="${4:-0}"
  local have_aerospace=0 focused=1 settled=0 i err wid

  if zathura_have_aerospace; then
    have_aerospace=1
    focused=0
  fi

  for i in $(seq 1 50); do
    sleep 0.1

    if err="$(zathura_launch_error "$log")" && [[ -n "$err" ]]; then
      printf '\n%s: zathura opened a window but could not read the document.\n' "$prog" >&2
      zathura_launch_detail "$log" | sed 's/^/  /' >&2
      printf '\n' >&2
      # Names the usual cause: the pdf plugins are built from source against
      # whatever mupdf/poppler was installed that day and are never rebuilt
      # when those upgrade, which kills epub support while pdfs carry on.
      if command -v check-zathura-plugins >/dev/null 2>&1; then
        check-zathura-plugins >&2 || true
      fi
      printf '\nfull output: %s\n' "$log" >&2
      if (( linger > 0 )); then
        sleep "$linger"
      fi
      return 1
    fi

    if (( have_aerospace )) && (( ! focused )); then
      wid="$(zathura_ids | sort -n | tail -n1)"
      if [[ -n "$wid" && "$wid" -gt "$before_max" ]]; then
        aerospace focus --window-id "$wid"
        focused=1
        settled=$i
      fi
    elif (( focused )) && (( i - settled >= 10 )); then
      break
    fi
  done

  return 0
}
