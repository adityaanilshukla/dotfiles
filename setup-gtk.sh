#!/usr/bin/env bash
# Apply the GTK theme settings.
#
# The gtk-3.0/gtk-4.0 settings.ini files are symlinked by setup-symlinks.sh, but
# they are only half the story: GTK4/libadwaita apps and anything going through
# the XDG settings portal read their theme from gsettings instead. Those values
# live in dconf (~/.local/share/dconf/user), a per-machine binary database that
# cannot be a symlinked dotfile -- so a machine keeps whatever was set by hand,
# possibly years ago.
#
# That is how buffyx ended up pinned to "Adwaita-dark", a theme name that exists
# on no machine here (90c5eb0 fixed the .ini files but could not reach dconf).
# GTK silently falls back to its default light theme when pointed at a missing
# theme, so only the apps consulting gsettings looked wrong -- which is why it
# read as "some GTK apps ignore my theme".
#
# Safe to run repeatedly; gsettings set is idempotent.

set -euo pipefail

info() { printf '    %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v gsettings >/dev/null 2>&1 || die "gsettings not found (install glib2)"

# gsettings needs a session bus. Without one it either errors or writes to a
# backend that is discarded, so fail loudly rather than appearing to succeed.
[[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] \
  || die "no D-Bus session bus -- run this from inside your graphical session"

set_key() {
  local key=$1 want=$2 have
  have="$(gsettings get org.gnome.desktop.interface "$key" 2>/dev/null || echo '?')"
  if [[ $have == "'$want'" ]]; then
    info "$key already '$want'"
  else
    gsettings set org.gnome.desktop.interface "$key" "$want"
    info "$key: $have -> '$want'"
  fi
}

# GTK3 dark is driven by GTK_THEME=Adwaita:dark from x/xprofile, not by any of
# the settings below -- on GTK 3.24.52 the rewritten Adwaita ignores
# gtk-application-prefer-dark-theme, and neither "Adwaita-dark" nor
# "AdwaitaDark" is a name it resolves. The keys below still matter for
# GTK4/libadwaita apps, which follow color-scheme.
#
# /etc/environment is root-owned and outside this repo, so warn rather than
# silently leave a machine half-themed.
if grep -qs '^GTK_THEME=' /etc/environment; then
  cur="$(grep -m1 '^GTK_THEME=' /etc/environment | cut -d= -f2-)"
  if [ "$cur" != "Adwaita:dark" ]; then
    printf '    WARNING: /etc/environment sets GTK_THEME=%s\n' "$cur"
    printf '      That value seeds the systemd user environment, so D-Bus-activated\n'
    printf '      services (notably xdg-desktop-portal-gtk, which draws file choosers)\n'
    printf '      inherit it and render light. Fix with:\n'
    printf '        sudo sed -i "s|^GTK_THEME=.*|GTK_THEME=Adwaita:dark|" /etc/environment\n'
  fi
fi

set_key icon-theme   "Qogir-Dark"
set_key color-scheme "prefer-dark"
# "Adwaita" plus prefer-dark is the modern way to get dark GTK. Do NOT set
# "Adwaita-dark": it no longer ships, and GTK degrades to light without warning.
set_key gtk-theme    "Adwaita"
