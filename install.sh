#!/usr/bin/env bash
#
# One job: run the install steps in order.
#
# Every step lives in install.d/ and does exactly one thing. This file decides
# what runs and in what order, and nothing else -- if you are adding setup
# logic, it belongs in a step, not here.
#
#   ./install.sh              run every step, in numeric order
#   ./install.sh 55           run only the step whose name matches "55"
#   ./install.sh symlinks     same, matching on name instead of number
#   ./install.sh --list       show the steps and stop
#
# Being able to run one step is the reason for the split. Re-linking configs
# after adding one is `./install.sh symlinks`, three seconds, instead of
# re-running a Homebrew check and a VS Code extension sync to get to it.
#
# ORDER IS LOAD-BEARING and the numbers encode it. The dependencies that
# actually bite, each documented in the step that owns it:
#   45-oh-my-zsh   before 55-symlinks   or its installer replaces our ~/.zshrc
#   55-symlinks    before 65-tmux       or tpm sources a ~/.tmux.conf that is
#                                       not there yet and installs no plugins
#   55-symlinks    before 75-claude     or the hook it registers points at
#                                       a file that does not exist
#   10-homebrew    before nearly all    almost everything is guarded on a
#                                       binary the Brewfile provides
#
# A failing step does NOT abort the run. A keyboard remapper or a VS Code
# extension failing must not stop a machine setup half-built; the failures are
# collected and reported together at the end instead.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
# shellcheck source=install.d/_lib.sh
source "$DOTFILES_DIR/install.d/_lib.sh"

STEP_DIR="$DOTFILES_DIR/install.d"

usage() {
  printf 'usage: %s [--list] [filter]\n\n' "$0"
  printf '  no argument   run every step in order\n'
  printf '  filter        run only steps whose filename contains this\n'
  printf '  --list        list the steps without running anything\n'
}

list_steps() {
  local path
  printf '%sSteps in %s:%s\n\n' "$C_BOLD" "${STEP_DIR/#$HOME/\~}" "$C_OFF"
  for path in "$STEP_DIR"/[0-9][0-9]-*.sh; do
    [[ -e "$path" ]] || continue
    printf '  %s\n' "$(basename "$path" .sh)"
  done
  printf '\n'
}

main() {
  local filter="" path name failed=() ran=0

  case "${1:-}" in
    --list)       list_steps; return 0 ;;
    -h|--help)    usage;      return 0 ;;
    -*)           usage >&2;  return 2 ;;
    *)            filter="${1:-}" ;;
  esac

  [[ -d "$STEP_DIR" ]] || die "no install.d directory beside this script"

  for path in "$STEP_DIR"/[0-9][0-9]-*.sh; do
    # The glob is literal when nothing matches, so check before running it.
    [[ -e "$path" ]] || die "install.d contains no steps"
    name="$(basename "$path" .sh)"
    [[ -n "$filter" && "$name" != *"$filter"* ]] && continue
    [[ -x "$path" ]] || die "step is not executable: $name"

    ran=$((ran + 1))
    # Deliberately not `set -e`-fatal: collect and carry on. A step is
    # responsible for its own internal error handling; this only records that
    # it came back non-zero so the summary can name it.
    "$path" || failed+=("$name")
  done

  if [[ $ran -eq 0 ]]; then
    die "no step matched '$filter' — try --list"
  fi

  printf '\n'
  if [[ ${#failed[@]} -gt 0 ]]; then
    printf '%s%d of %d steps failed:%s\n' "$C_YELLOW$C_BOLD" "${#failed[@]}" "$ran" "$C_OFF"
    # One printf per entry: passing "${failed[@]}" to a three-slot format
    # string silently mangles the output as soon as more than one step fails.
    for name in "${failed[@]}"; do
      printf '  %s%s%s\n' "$C_YELLOW" "$name" "$C_OFF"
    done
    printf '\nRe-run just one with: %s%s <name>%s\n\n' "$C_BOLD" "$0" "$C_OFF"
    return 1
  fi

  printf '%s%d steps completed.%s\n\n' "$C_GREEN$C_BOLD" "$ran" "$C_OFF"
}

main "$@"
