#!/usr/bin/env bash
#
# One job: the handful of things every install step needs, so no step has to
# redefine them and drift.
#
# Named with a leading underscore rather than a number on purpose: the runner
# globs [0-9][0-9]-*.sh, so this is sourced by steps and never executed as one.
#
# Every step sources this and can therefore be run on its own:
#     ./install.d/55-symlinks.sh
# which is the point of splitting them up. Re-running one step must be as safe
# as re-running all of them, so steps stay idempotent.

# Guard against double-sourcing when a step is invoked from the runner, which
# has already sourced this itself.
[[ -n "${DOTFILES_LIB_SOURCED:-}" ]] && return 0
DOTFILES_LIB_SOURCED=1

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
export DOTFILES_DIR

# --- Output ---------------------------------------------------------------
# Colour only when stdout is a terminal and NO_COLOR is unset, so piping the
# install to a log file does not embed escape codes.
# shellcheck disable=SC2034  # these are consumed by the steps that source this
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'; C_OFF=$'\e[0m'
  C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'
else
  C_BOLD=''; C_DIM=''; C_OFF=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

# step: the banner a step prints when it starts.
step() { printf '\n%s==>%s %s%s%s\n' "$C_BLUE$C_BOLD" "$C_OFF" "$C_BOLD" "$*" "$C_OFF"; }

# info/ok/warn: ordinary progress, success, and "this did not work but the
# install carries on". warn goes to stderr so `./install.sh 2>warnings.log`
# collects exactly the things that need a human.
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
warn() { printf '    %s!!%s %s\n' "$C_YELLOW$C_BOLD" "$C_OFF" "$*" >&2; }
die()  { printf '%sfatal:%s %s\n' "$C_RED$C_BOLD" "$C_OFF" "$*" >&2; exit 1; }

# --- Preconditions --------------------------------------------------------
# NASA rule 5, in the only form that means anything for a shell script: assert
# what the step needs before it acts, so a failure names its cause instead of
# surfacing three steps later as something unrelated.
require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "this step only runs on macOS"
}

require_dotfiles_dir() {
  [[ -d "$DOTFILES_DIR" ]] || die "DOTFILES_DIR does not exist: $DOTFILES_DIR"
}

# have: does this command exist? Used everywhere in place of a bare
# `command -v x >/dev/null 2>&1`.
have() { command -v "$1" >/dev/null 2>&1; }

# brew_shellenv: put brew on PATH for a step that needs it. A step run on its
# own does not inherit the PATH the Homebrew step set up, so any step depending
# on a brew-installed binary calls this first.
brew_shellenv() {
  have brew && return 0
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

require_dotfiles_dir
