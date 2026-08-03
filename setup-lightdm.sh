#!/usr/bin/env bash
# Install the login screen: LightDM + slick-greeter, identical on every machine.
#
# WHY THIS SCRIPT IS DIFFERENT FROM THE REST OF THE REPO
#
# This is the only script here that writes to /etc and needs root. That breaks
# an invariant the other scripts hold deliberately -- setup-symlinks.sh only
# links into $HOME, and setup-gtk.sh explicitly refuses to touch
# /etc/environment and merely prints the sudo command for you to run. The
# exception is justified because a login screen is inherently system state:
# it runs before any user session exists, as the unprivileged `lightdm` user,
# so there is no per-user equivalent to write instead.
#
# It COPIES rather than symlinks, which is the other deviation. LightDM parses
# its config as root, and that config has display-setup-script,
# greeter-setup-script and session-wrapper keys -- all root-executed command
# paths. Symlinking them to a user-writable path under $HOME would turn any
# compromise of this account into root code execution at boot. Copies also
# survive /home failing to mount, which a symlinked login screen would not.
#
# Copies drift, so drift is made loud: files are compared before writing and a
# mismatch prints a diff and refuses unless FORCE=1.
#
# WHY LIGHTDM ON NVIDIA IS FINE
#
# brovo ran sddm because "nvidia didn't work with lightdm". pacman.log says the
# real cause was the driver: lightdm was configured on 2025-11-29 at 18:56, two
# minutes after nvidia-dkms (the CLOSED module) was installed on a GB206
# RTX 5060 Ti. Blackwell is supported only by the open modules, so the card had
# no working driver at all. nvidia-open-dkms landed 2025-11-30 05:19 and sddm
# only arrived 2025-12-02, two days after the fix -- so sddm "working" was
# coincidence, not causation.
#
# IF THE LOGIN SCREEN DOES NOT COME BACK AFTER A REBOOT
#
# Switch to a TTY with Ctrl+Alt+F2 and run:
#
#     sudo systemctl disable lightdm.service
#     sudo systemctl enable --force sddm.service
#     sudo systemctl reboot
#
# sddm is deliberately left installed on brovo for exactly this. If LightDM
# loops and steals every VT so Ctrl+Alt+F2 does not work, append
#
#     systemd.unit=multi-user.target
#
# to the kernel line at the bootloader, boot to a text console, then run the
# commands above.
#
# Usage:
#   ./setup-lightdm.sh                 # install config only (safe, default)
#   SWITCH_DM=1 ./setup-lightdm.sh     # also make lightdm the display manager
#   FORCE=1 ./setup-lightdm.sh         # overwrite locally-modified /etc files
#   DRY_RUN=1 ./setup-lightdm.sh       # print what would happen, change nothing

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
SRC_DIR="$DOTFILES_DIR/lightdm"
DRY_RUN="${DRY_RUN:-0}"
FORCE="${FORCE:-0}"
SWITCH_DM="${SWITCH_DM:-0}"

GREETER=lightdm-slick-greeter
WALLPAPER_DIR=/usr/share/backgrounds/dotfiles

log()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    \033[33mwarning:\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if [[ $DRY_RUN == 1 ]]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

[[ -d $SRC_DIR ]] || die "lightdm config not found at $SRC_DIR"
command -v pacman >/dev/null || die "this script is Arch-only (no pacman found)"

# --- preflight ---------------------------------------------------------------
# These run before sudo so a machine that cannot possibly work fails fast and
# free, rather than after prompting for a password.

# The landmine. /etc/lightdm/lightdm.conf naming a greeter that is not installed
# is a silent failure: LightDM starts, finds no .desktop to launch, and leaves a
# black screen with no error in the journal worth reading. brovo sat in exactly
# this state from 2025-12-13. Fatal, never a warning.
if [[ ! -f /usr/share/xgreeters/$GREETER.desktop ]]; then
  info "installed greeters: $(find /usr/share/xgreeters/ -name '*.desktop' -printf '%f ' 2>/dev/null)"
  die "$GREETER is not installed (no /usr/share/xgreeters/$GREETER.desktop).
       LightDM would start and render nothing. Install it first:
         sudo pacman -S $GREETER"
fi

# The greeter runs as this user. Without it LightDM cannot start a session.
getent passwd lightdm >/dev/null || die "the 'lightdm' user does not exist -- reinstall the lightdm package"

# --- warnings ----------------------------------------------------------------
# Everything below is recoverable or cosmetic, so warn and keep going.

# lightdm.conf is read AFTER lightdm.conf.d/*.conf, so it wins. If it pins a
# different greeter, our drop-in is silently inert and the login screen will not
# be the one in this repo.
existing_greeter="$(sed -nE 's/^[[:space:]]*greeter-session[[:space:]]*=[[:space:]]*(.*)$/\1/p' \
  /etc/lightdm/lightdm.conf 2>/dev/null | tail -1)"
if [[ -n $existing_greeter && $existing_greeter != "$GREETER" ]]; then
  warn "/etc/lightdm/lightdm.conf sets greeter-session=$existing_greeter"
  warn "  That file is read AFTER lightdm.conf.d/, so it overrides our drop-in."
  warn "  Comment that line out, or the greeter in this repo will not be used."
fi

# A missing icon or cursor theme does not fail, it just renders wrong, which is
# harder to notice than a crash.
for key in icon-theme-name cursor-theme-name; do
  theme="$(sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*(.*)$/\1/p" "$SRC_DIR/slick-greeter.conf" | tail -1)"
  if [[ -n $theme && ! -d /usr/share/icons/$theme ]]; then
    warn "$key=$theme is not installed (/usr/share/icons/$theme missing); greeter will fall back"
  fi
done

# brovo depends on /etc/modprobe.d/nvidia-drm.conf, a hand-written file owned by
# no package, to get modeset=1. Without it the nvidia OutputClass never matches,
# Xorg falls back to modesetting, and you get a black screen -- under ANY display
# manager, sddm included. Outside this repo's scope (same call as setup-gtk.sh
# makes about /etc/environment), so warn rather than write it.
# /sys/module/nvidia_drm/parameters/modeset is root-only (0400), so test for
# KMS by its observable effect instead: connector nodes like card*-HDMI-A-1
# under /sys/class/drm only exist when a KMS driver has bound the card.
if lspci 2>/dev/null | grep -qi nvidia; then
  if ! compgen -G '/sys/class/drm/card*-*' >/dev/null; then
    warn "no KMS connector nodes under /sys/class/drm -- nvidia_drm modeset"
    warn "  looks OFF. Without KMS the nvidia Xorg OutputClass never matches"
    warn "  and you get a black screen under ANY display manager. Check"
    warn "  /etc/modprobe.d/ for 'options nvidia_drm modeset=1' -- that file"
    warn "  is owned by no package here."
  fi
fi

if [[ -f /etc/lightdm/lightdm.conf.pacnew ]]; then
  warn "/etc/lightdm/lightdm.conf.pacnew exists -- reconcile it with pacdiff"
fi

# --- sudo --------------------------------------------------------------------
# Ask once, up front, rather than prompting midway through writing /etc.
if [[ $DRY_RUN != 1 ]]; then
  log "Requesting sudo (needed to write /etc/lightdm)"
  sudo -v || die "sudo required"
fi

# --- install -----------------------------------------------------------------
# Idempotent, and drift-aware in both directions. After every install a copy of
# what was written is kept in $STAMP_DIR. That lets the next run tell apart the
# two ways dest can differ from the repo:
#
#   dest == stamp   the file is untouched since we last wrote it; the REPO
#                   moved ahead. Updating is exactly what the user asked for,
#                   so do it without ceremony.
#   dest != stamp   someone edited /etc directly (lightdm-settings on kalu
#                   does this). Show the diff and refuse without FORCE=1,
#                   because silently clobbering local edits is how machines
#                   diverge invisibly.
#
# Without the stamp every legitimate repo change would demand FORCE=1, which
# trains the habit of always passing FORCE and defeats the check entirely.
STAMP_DIR=/var/lib/dotfiles/lightdm

install_file() {
  local src=$1 dest=$2 stamp
  stamp="$STAMP_DIR/$(basename "$dest")"
  [[ -f $src ]] || die "missing source file: $src"

  # Comparisons need no sudo: everything this script installs is 0644, so read
  # them as the invoking user. Only the writes below are privileged. This also
  # keeps DRY_RUN genuinely password-free.
  if [[ -f $dest ]] && cmp -s "$src" "$dest"; then
    info "$dest already current"
    # Heal a missing stamp so the next repo update stays prompt-free.
    if [[ ! -f $stamp ]]; then
      run sudo install -Dm 0644 -o root -g root "$src" "$stamp"
    fi
    return
  fi

  if [[ -f $dest && $FORCE != 1 ]] && ! cmp -s "$dest" "$stamp"; then
    # Not what we last installed: hand-edited, or never managed by us at all.
    printf '\n'
    warn "$dest differs from the repo AND from what this script last installed:"
    diff -u "$dest" "$src" | sed 's/^/      /' || true
    printf '\n'
    die "refusing to overwrite $dest.
       Re-run with FORCE=1 to replace it, or copy the change back into
       $src and commit it."
  fi

  # Back up anything that was there before we ever managed this path, once.
  if [[ -f $dest && ! -f $dest.bak && ! -f $stamp ]]; then
    run sudo cp -a "$dest" "$dest.bak"
    info "backed up $dest -> $dest.bak"
  fi

  run sudo install -Dm 0644 -o root -g root "$src" "$dest"
  run sudo install -Dm 0644 -o root -g root "$src" "$stamp"
  info "installed $dest"
}

log "Login screen config"
install_file "$SRC_DIR/backgrounds/space-shuttle.jpg" "$WALLPAPER_DIR/space-shuttle.jpg"
install_file "$SRC_DIR/lightdm.conf.d/10-dotfiles.conf" /etc/lightdm/lightdm.conf.d/10-dotfiles.conf
install_file "$SRC_DIR/slick-greeter.conf" /etc/lightdm/slick-greeter.conf

# --- display manager ---------------------------------------------------------
# Opt-in. Installing config is safe to repeat on every bootstrap; changing which
# display manager boots the machine is not, so it needs an explicit flag.
current_dm() {
  local target
  target="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" || return 0
  [[ -n $target ]] && basename "$target"
  return 0
}

if [[ $SWITCH_DM == 1 ]]; then
  log "Display manager"
  dm="$(current_dm)"
  if [[ $dm == lightdm.service ]]; then
    info "lightdm is already the display manager"
  else
    info "currently: ${dm:-none}"
    # display-manager.service is an Alias= symlink that both units claim, so a
    # plain `enable` fails with "File ... already exists". Disable the incumbent
    # first, then --force to repoint the alias unconditionally.
    if [[ -n $dm ]]; then
      run sudo systemctl disable "$dm"
    fi
    run sudo systemctl enable --force lightdm.service
    run sudo systemctl daemon-reload
    if [[ $DRY_RUN != 1 ]]; then
      info "now: $(current_dm)"
    fi
  fi
  printf '\n'
  info "Reboot to apply. Do NOT 'systemctl restart display-manager' from inside"
  info "your session -- it kills the session you are typing in."
  info ""
  info "If the login screen does not come back, Ctrl+Alt+F2 and run:"
  info "    sudo systemctl disable lightdm.service"
  info "    sudo systemctl enable --force sddm.service"
  info "    sudo systemctl reboot"
else
  log "Display manager"
  dm="$(current_dm)"
  info "currently: ${dm:-none}"
  info "not switching (re-run with SWITCH_DM=1 to make lightdm the display manager)"
fi

log "Done."
info "Preview the greeter without rebooting:"
info "    Xephyr :1 -screen 1600x900 &"
info "    DISPLAY=:1 lightdm --test-mode --debug"
info "Check which config files actually took effect:"
info "    lightdm --show-config"
