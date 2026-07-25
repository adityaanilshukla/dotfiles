#!/usr/bin/env bash
# Install the Hack Nerd Font used across this setup.
#
# Why this exists: the font is NOT installed from a package on any machine here.
# `pacman -Qo` finds no owner for the file on brovo, and buffyx has no
# ttf-hack-nerd package either -- both were populated by hand, so a new machine
# silently ends up without it. That matters because several things depend on the
# patched glyphs and degrade to empty boxes without them, with no error:
#
#   - the volume/brightness OSD in I3-wm-config (bash-files/hud.sh)
#   - dunstrc's `font = HackNerdFont-Regular 8`
#   - polybar and alacritty
#
# Installs per-user into ~/.local/share/fonts, matching where the existing
# files already live. No root required.
#
# Note: on Arch, `pacman -S ttf-hack-nerd` is the better option -- it is
# updated with the system and owned by the package manager. Use this script
# when you want the exact upstream release pinned, or on a non-Arch machine.
#
# Usage:
#   ./install-hack-nerd-font.sh            # install pinned version if missing
#   FORCE=1 ./install-hack-nerd-font.sh    # reinstall even if present
#   NERD_FONT_VERSION=3.4.0 ./install-hack-nerd-font.sh
#   FONT_DEST=/tmp/x ./install-hack-nerd-font.sh   # test without touching ~

set -euo pipefail

# Pinned to what is already installed on brovo and buffyx (Hack 3.003 /
# Nerd Fonts 3.4.0), so running this does not silently change how anything
# renders. Bump deliberately.
VERSION="${NERD_FONT_VERSION:-3.4.0}"
DEST="${FONT_DEST:-$HOME/.local/share/fonts}"
FORCE="${FORCE:-0}"

# Which styles to install, comma-separated. Each is ~2.6 MB, so this is the
# only real size lever:
#
#   Regular                        2.6 MB  (what these machines had historically)
#   Regular,Bold                   5.2 MB  (default: real bold instead of a
#                                           synthesised fake in the terminal)
#   Regular,Bold,Italic,BoldItalic  11 MB
#
# For comparison, Arch's ttf-hack-nerd is 30.75 MB, because it also ships the
# Mono and Propo families -- 12 files where these configs only ever name the
# proportional "HackNerdFont-*" one. Those are deliberately skipped here, both
# to save space and to stop fontconfig having three near-identical families to
# choose between.
STYLES="${STYLES:-Regular,Bold}"

URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${VERSION}/Hack.zip"

log() { printf '  %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for tool in curl unzip fc-cache fc-query; do
  command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

# Idempotence. fc-query reports the font's own version field; Hack 3.003 is the
# release shipped inside Nerd Fonts 3.4.0. Checking the file we would install,
# rather than asking fontconfig, avoids matching a differently-named family.
installed_ok() {
  local f="$DEST/HackNerdFont-Regular.ttf"
  [[ -f $f ]] || return 1
  fc-query -f '%{fontversion}' "$f" >/dev/null 2>&1 || return 1
  return 0
}

if [[ $FORCE != 1 ]] && installed_ok; then
  log "Hack Nerd Font already present in $DEST -- nothing to do (FORCE=1 to reinstall)."
  fc-match 'HackNerdFont-Regular' | sed 's/^/  now: /'
  exit 0
fi

tmp="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" EXIT

log "Downloading Hack.zip from Nerd Fonts v${VERSION}..."
curl -fsSL --retry 3 --retry-delay 2 -o "$tmp/Hack.zip" "$URL" \
  || die "download failed: $URL"

# Guard against a truncated download or an HTML error page saved as .zip.
unzip -tqq "$tmp/Hack.zip" >/dev/null 2>&1 || die "downloaded file is not a valid zip"

patterns=()
IFS=',' read -ra _styles <<< "$STYLES"
for s in "${_styles[@]}"; do
  s="${s// /}"
  [[ -n $s ]] && patterns+=("HackNerdFont-${s}.ttf")
done
(( ${#patterns[@]} > 0 )) || die "STYLES is empty"

log "Extracting: ${patterns[*]}"
unzip -joq "$tmp/Hack.zip" "${patterns[@]}" -d "$tmp/fonts" \
  || die "archive has no files matching: ${patterns[*]} (check STYLES)"

shopt -s nullglob
extracted=("$tmp/fonts"/*.ttf)
(( ${#extracted[@]} > 0 )) || die "extraction produced no .ttf files"

# Validate every file actually parses as a font before putting it in place, so a
# corrupt download cannot half-install and leave boxes on screen.
for f in "${extracted[@]}"; do
  fc-query "$f" >/dev/null 2>&1 || die "not a valid font file: $(basename "$f")"
done

mkdir -p "$DEST"
install -m 0644 "${extracted[@]}" "$DEST/"
log "Installed ${#extracted[@]} file(s) into $DEST:"
printf '    %s\n' "${extracted[@]##*/}"

log "Rebuilding font cache..."
fc-cache -f "$DEST" >/dev/null

# Verify the name everything actually asks for resolves to what we installed,
# not to a fallback. fc-match never fails; it returns whatever is closest. So
# compare the resolved family rather than trusting the exit code.
resolved="$(fc-match 'HackNerdFont-Regular' -f '%{family}')"
case "$resolved" in
  *"Hack Nerd Font"*) log "Verified: 'HackNerdFont-Regular' resolves to '$resolved'" ;;
  *) die "font installed but fontconfig still resolves to '$resolved'" ;;
esac
