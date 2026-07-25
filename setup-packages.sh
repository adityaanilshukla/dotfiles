#!/usr/bin/env bash
# Install every package this setup depends on.
#
# One script, two data files. The machines differ only in *which list to read*;
# the work of installing is identical, so it lives here once. Two scripts would
# mean two copies of that logic, and copies drift -- which is exactly how
# brightness.sh kept a stale on-screen display for months after its sibling was
# rewritten.
#
# Profile selection is automatic:
#   NVIDIA GPU present -> "nvidia" (brovo, the desktop)
#   otherwise          -> "intel"  (buffyx/XPS, the T480)
#
# Usage:
#   ./setup-packages.sh                 # detect profile, install everything
#   PROFILE=intel ./setup-packages.sh   # force a profile
#   DRY_RUN=1 ./setup-packages.sh       # print what would happen, change nothing

set -euo pipefail

# Byte collation for the whole script. `comm` compares using its own locale, so
# feeding it `LC_ALL=C sort`ed input while comm itself runs under en_US.UTF-8
# silently produces garbage -- it reported installed packages as missing. Both
# sides of every comparison must agree, so pin it once here rather than per call.
export LC_ALL=C

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LIST_DIR="$DOTFILES_DIR/packagelist"
DRY_RUN="${DRY_RUN:-0}"

log()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
run()  { if [[ $DRY_RUN == 1 ]]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

[[ -d $LIST_DIR ]] || die "package lists not found at $LIST_DIR"
command -v pacman >/dev/null || die "this script is Arch-only (no pacman found)"

# --- profile -----------------------------------------------------------------
# lspci is the reliable discriminator here: brovo reports an NVIDIA VGA
# controller and loads the nvidia modules; buffyx reports Intel Iris Xe and
# loads none. Note the lists are *named* for the GPU but really encode
# desktop-vs-laptop; that happens to coincide today.
detect_profile() {
  if lspci 2>/dev/null | grep -qi 'nvidia'; then echo nvidia; else echo intel; fi
}
PROFILE="${PROFILE:-$(detect_profile)}"
[[ -f "$LIST_DIR/$PROFILE-pacman.txt" ]] || die "unknown profile '$PROFILE' (no $PROFILE-pacman.txt)"

log "Profile: $PROFILE"
info "$(lspci 2>/dev/null | grep -iE 'vga|3d controller' | head -1 | cut -d: -f3- | sed 's/^ //')"

# --- sudo --------------------------------------------------------------------
# Ask once, up front, rather than having pacman prompt in the middle of a long
# run. Also fails fast if the user has no sudo rights at all.
if [[ $DRY_RUN != 1 ]]; then
  log "Requesting sudo (needed for pacman)"
  sudo -v || die "sudo required"
fi

# --- paru --------------------------------------------------------------------
# Chicken and egg: the AUR list needs an AUR helper, but paru is itself only in
# the AUR. So it cannot come from the list -- it has to be built from source
# first, which needs base-devel and git.
ensure_paru() {
  if command -v paru >/dev/null 2>&1; then
    info "paru already present ($(paru --version 2>/dev/null | head -1))"
    return
  fi
  log "Bootstrapping paru from the AUR (not available in official repos)"
  run sudo pacman -S --needed --noconfirm base-devel git
  local tmp; tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  run git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
  if [[ $DRY_RUN != 1 ]]; then
    ( cd "$tmp/paru" && makepkg -si --noconfirm )
  else
    info "[dry-run] makepkg -si --noconfirm in $tmp/paru"
  fi
}

# --- install -----------------------------------------------------------------
# --needed makes this idempotent: already-installed packages are skipped rather
# than reinstalled, so re-running is cheap and safe.
install_native() {
  local list="$LIST_DIR/$PROFILE-pacman.txt" missing=()
  [[ -f $list ]] || return 0
  mapfile -t missing < <(comm -23 <(LC_ALL=C sort -u "$list") <(pacman -Qq | LC_ALL=C sort -u))
  if (( ${#missing[@]} == 0 )); then
    log "Official packages: all $(wc -l < "$list") already installed"
    return
  fi
  log "Official packages: installing ${#missing[@]} missing of $(wc -l < "$list")"
  printf '    %s\n' "${missing[@]}"
  run sudo pacman -S --needed --noconfirm -- "${missing[@]}"
}

install_aur() {
  local list="$LIST_DIR/$PROFILE-aur.txt" missing=()
  [[ -f $list ]] || return 0
  mapfile -t missing < <(comm -23 <(LC_ALL=C sort -u "$list") <(pacman -Qq | LC_ALL=C sort -u))
  if (( ${#missing[@]} == 0 )); then
    log "AUR packages: all $(wc -l < "$list") already installed"
    return
  fi
  log "AUR packages: installing ${#missing[@]} missing of $(wc -l < "$list")"
  printf '    %s\n' "${missing[@]}"
  run paru -S --needed --noconfirm -- "${missing[@]}"
}

install_native
ensure_paru
install_aur

log "Done."
info "Regenerate the lists after installing things by hand:"
info "  pacman -Qqen > $LIST_DIR/$PROFILE-pacman.txt"
info "  pacman -Qqem > $LIST_DIR/$PROFILE-aur.txt"
