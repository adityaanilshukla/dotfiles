#!/usr/bin/env bash
# One command to set up a new machine, or to update an existing one.
#
# This exists because "update my setup" used to mean two `git pull`s in two
# different repos plus several remembered manual steps -- and the steps that got
# forgotten (packages, fonts, gsettings) are exactly the ones that caused
# machines to silently diverge. Everything below is idempotent, so running this
# on a working machine is a no-op update rather than a reinstall.
#
# Order matters: packages first (so later steps have their tools), then
# symlinks, then the things that need a graphical session.
#
# Usage:
#   ./bootstrap.sh                  # everything
#   ./bootstrap.sh packages fonts   # only the named steps
#   DRY_RUN=1 ./bootstrap.sh        # show what would happen
#   SKIP_REPOS=1 ./bootstrap.sh     # don't touch git, just run the setup steps

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
I3_DIR="${I3_DIR:-$HOME/.config/i3}"
DRY_RUN="${DRY_RUN:-0}"
SKIP_REPOS="${SKIP_REPOS:-0}"

# HTTPS, not SSH, so this works on a fresh machine before any key is on GitHub.
# An existing clone keeps whatever remote it already has; we never rewrite it.
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/adityaanilshukla/dotfiles.git}"
I3_REPO="${I3_REPO:-https://github.com/adityaanilshukla/I3-wm-config.git}"

log()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    \033[33mwarning:\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if [[ $DRY_RUN == 1 ]]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

clone_or_pull() {
  local repo=$1 dir=$2 name=$3
  if [[ -d $dir/.git ]]; then
    info "$name: already cloned, pulling"
    # --ff-only refuses rather than creating a merge commit if local work
    # diverged. A surprise merge in a dotfiles repo is worse than a clear error.
    if [[ $DRY_RUN == 1 ]]; then
      info "[dry-run] git -C $dir pull --ff-only"
    elif ! git -C "$dir" pull --ff-only 2>&1 | sed 's/^/      /'; then
      warn "$name: pull failed (local changes or diverged branch). Continuing."
    fi
  elif [[ -e $dir ]]; then
    warn "$name: $dir exists but is not a git repo -- leaving it alone."
    warn "  Move it aside and re-run if you want it managed by git."
  else
    info "$name: cloning into $dir"
    run git clone "$repo" "$dir"
  fi
}

step_repos() {
  log "Repositories"
  command -v git >/dev/null || die "git is required to bootstrap"
  clone_or_pull "$DOTFILES_REPO" "$DOTFILES_DIR" "dotfiles"
  clone_or_pull "$I3_REPO"       "$I3_DIR"       "I3-wm-config"
}

step_packages() { log "Packages";  run "$DOTFILES_DIR/setup-packages.sh"; }
step_symlinks() { log "Symlinks";  run "$DOTFILES_DIR/setup-symlinks.sh"; }
step_fonts()    { log "Fonts";     run "$DOTFILES_DIR/setup-fonts.sh"; }

# The only step that writes to /etc and needs root, which is why it is its own
# script rather than part of setup-symlinks.sh. It installs the login screen
# config but does NOT change which display manager boots the machine -- that
# needs SWITCH_DM=1 passed explicitly, so a routine bootstrap can never leave
# you staring at a machine that will not log in.
step_lightdm()  { log "Login screen"; run "$DOTFILES_DIR/setup-lightdm.sh"; }

step_gtk() {
  log "GTK theme"
  # Needs a live session bus; over SSH or on a TTY there is nothing to talk to,
  # and gsettings would either fail or write somewhere that gets discarded.
  if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
    warn "no D-Bus session -- skipping."
    warn "  Run ./setup-gtk.sh from inside your graphical session."
    return 0
  fi
  run "$DOTFILES_DIR/setup-gtk.sh"
}

# lightdm sits after fonts (it needs `packages` to have installed the greeter)
# and before gtk (which must stay last -- it needs a live D-Bus session).
ALL_STEPS=(repos packages symlinks fonts lightdm gtk)
steps=("$@")
(( ${#steps[@]} == 0 )) && steps=("${ALL_STEPS[@]}")
[[ $SKIP_REPOS == 1 ]] && steps=("${steps[@]/repos}")

for s in "${steps[@]}"; do
  [[ -z $s ]] && continue
  case "$s" in
    repos)    step_repos ;;
    packages) step_packages ;;
    symlinks) step_symlinks ;;
    fonts)    step_fonts ;;
    lightdm)  step_lightdm ;;
    gtk)      step_gtk ;;
    *)        die "unknown step '$s' (valid: ${ALL_STEPS[*]})" ;;
  esac
done

log "Bootstrap complete."
info "Things this deliberately cannot do for you:"
info "  - swap the git remotes to SSH (it clones over HTTPS so a fresh"
info "    machine works before your key is on GitHub)"
info "  - decrypt secrets.gpg (needs your GPG key and passphrase)"
info "  - BIOS settings, e.g. the Fn-lock behaviour on the XPS"
