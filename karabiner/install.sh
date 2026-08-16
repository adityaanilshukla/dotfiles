#!/usr/bin/env bash
#
# Karabiner-Elements module installer.
#
# Idempotent: safe to run any number of times. Generates the ruleset from
# spec.json, symlinks it into Karabiner's assets directory, and merges the rules
# into the active profile in ~/.config/karabiner/karabiner.json.
#
# Packages come from the Brewfile (karabiner-elements, jq), not from here, so
# this script installs nothing — the top-level install.sh runs `brew bundle`
# first. Run standalone it fails loudly if either is missing.
#
# What it CANNOT do: grant the driver-extension and Input Monitoring
# permissions. Those are TCC/SIP protected and require physical clicks. The
# script detects whether they are already granted and prints an ACTION REQUIRED
# block if not.

set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KARABINER_DIR="${HOME}/.config/karabiner"
CONFIG="${KARABINER_DIR}/karabiner.json"
ASSETS_DIR="${KARABINER_DIR}/assets/complex_modifications"
SPEC="${MODULE_DIR}/spec.json"
RULES_SRC="${MODULE_DIR}/rules/managed.json"
RULES_LINK="${ASSETS_DIR}/managed.json"

# --------------------------------------------------------------------------
# output helpers
# --------------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_OK=''; C_WARN=''; C_ERR=''; C_DIM=''; C_OFF=''
fi

info()  { printf '%s[karabiner]%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
ok()    { printf '%s[karabiner]%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn()  { printf '%s[karabiner]%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }
die()   { printf '%s[karabiner]%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

# --------------------------------------------------------------------------
# preflight
# --------------------------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "macOS only (uname reports $(uname -s))"
[[ "${EUID}" -ne 0 ]] || die "do not run this as root"
[[ -f "${SPEC}" ]] || die "spec.json not found in ${MODULE_DIR}"

command -v jq >/dev/null 2>&1 \
  || die "jq not found — run 'brew bundle --file=$HOME/dotfiles/Brewfile' first"

if [[ ! -d "/Applications/Karabiner-Elements.app" ]]; then
  die "Karabiner-Elements not installed — run 'brew bundle --file=$HOME/dotfiles/Brewfile' first"
fi

# The rule descriptions this module owns all start with this. Read from the
# spec rather than hardcoded, so the prefix and the prune filter below cannot
# drift apart.
PREFIX="$(jq -r '.prefix // empty' "${SPEC}")"
[[ -n "${PREFIX}" ]] || die "spec.json has no \"prefix\" — refusing to merge without one to prune by"

# --------------------------------------------------------------------------
# generate ruleset from spec
# --------------------------------------------------------------------------
info "generating ruleset from spec.json"
python3 "${MODULE_DIR}/generate.py"
[[ -f "${RULES_SRC}" ]] || die "generator did not produce ${RULES_SRC}"

# Karabiner ships its own validator, which knows the things jq cannot check:
# whether every key_code and modifier name actually exists. Gate on it, so a
# typo in spec.json fails here instead of silently disabling a rule at runtime.
KARABINER_CLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
if [[ -x "${KARABINER_CLI}" ]]; then
  "${KARABINER_CLI}" --lint-complex-modifications "${RULES_SRC}" \
    || die "Karabiner rejected the generated ruleset — fix spec.json (live config untouched)"
fi

# --------------------------------------------------------------------------
# quit the settings UI before touching karabiner.json
#
# Karabiner-Elements.app (the settings window) rewrites karabiner.json from its
# in-memory state and will clobber external edits. The background daemon
# (karabiner_console_user_server) is a separate process and keeps remapping, so
# quitting the settings app costs nothing.
# --------------------------------------------------------------------------
if pgrep -x "Karabiner-Elements" >/dev/null 2>&1; then
  info "quitting Karabiner-Elements settings window"
  osascript -e 'quit app "Karabiner-Elements"' >/dev/null 2>&1 || true
  sleep 1
fi

# --------------------------------------------------------------------------
# symlink the asset
#
# Karabiner only ever reads assets/complex_modifications, so this one is safe to
# symlink into the repo. karabiner.json itself deliberately is not — see README.
# --------------------------------------------------------------------------
mkdir -p "${ASSETS_DIR}"
if [[ -L "${RULES_LINK}" && "$(readlink "${RULES_LINK}")" == "${RULES_SRC}" ]]; then
  info "asset symlink already correct"
else
  ln -sfn "${RULES_SRC}" "${RULES_LINK}"
  ok "linked ${RULES_LINK} -> ${RULES_SRC}"
fi

# --------------------------------------------------------------------------
# migrate away from the old symlink
#
# A symlink here means an older version of this repo linked karabiner.json into
# the dotfiles tree. Every merge would then write into the working tree and show
# up as a git diff, so replace it with a real file, keeping the content.
#
# This has to run BEFORE the bootstrap below. A symlink left over from a
# checkout that no longer has karabiner/karabiner.json is dangling, so `-f` is
# false and the bootstrap would `cat >` straight through the link and recreate
# that file inside the repo — the exact thing this module exists to stop.
# --------------------------------------------------------------------------
if [[ -L "${CONFIG}" ]]; then
  if [[ -e "${CONFIG}" ]]; then
    info "karabiner.json is a symlink to $(readlink "${CONFIG}"); replacing it with a real file"
    cat "${CONFIG}" > "${CONFIG}.real"   # cat reads through the link
    rm -f "${CONFIG}"
    mv "${CONFIG}.real" "${CONFIG}"
  else
    info "karabiner.json is a dangling symlink to $(readlink "${CONFIG}"); removing it"
    rm -f "${CONFIG}"
  fi
fi

# --------------------------------------------------------------------------
# bootstrap karabiner.json if this is a fresh machine
#
# The file does not exist until Karabiner has run once. Rather than requiring a
# launch, write a minimal valid config; Karabiner fills in the remaining keys.
# --------------------------------------------------------------------------
if [[ ! -f "${CONFIG}" ]]; then
  info "no karabiner.json found, writing a minimal one"
  mkdir -p "${KARABINER_DIR}"
  cat > "${CONFIG}" <<'EOF'
{
  "profiles": [
    {
      "name": "Default profile",
      "selected": true,
      "complex_modifications": {
        "parameters": {},
        "rules": []
      },
      "virtual_hid_keyboard": {
        "keyboard_type_v2": "ansi"
      }
    }
  ]
}
EOF
fi

jq empty "${CONFIG}" 2>/dev/null || die "${CONFIG} is not valid JSON - fix or remove it and re-run"

# --------------------------------------------------------------------------
# back up, then merge
# --------------------------------------------------------------------------
BACKUP_DIR="${KARABINER_DIR}/backups"
mkdir -p "${BACKUP_DIR}"
BACKUP="${BACKUP_DIR}/karabiner.json.$(date +%Y%m%d-%H%M%S)"
cp "${CONFIG}" "${BACKUP}"

# keep the 10 most recent backups
# shellcheck disable=SC2012
ls -1t "${BACKUP_DIR}"/karabiner.json.* 2>/dev/null | tail -n +11 | while read -r old; do
  rm -f "${old}"
done

TMP="$(mktemp "${TMPDIR:-/tmp}/karabiner.XXXXXX.json")"
trap 'rm -f "${TMP}"' EXIT

# PRUNE then append: drop every rule this module has ever installed (they all
# share $PREFIX) before adding the current set. That gives replace-not-duplicate
# semantics on a re-run, and deleting a group from spec.json actually removes it
# on the next one. Rules you added yourself in the GUI have no prefix and are
# left where they are.
jq --slurpfile incoming "${RULES_SRC}" --arg prefix "${PREFIX}" '
  ($incoming[0].rules) as $new
  | ((.profiles | map(.selected == true) | index(true)) // 0) as $i
  | .profiles[$i].complex_modifications.rules =
      (
        ((.profiles[$i].complex_modifications.rules // [])
          | map(select((.description // "") | startswith($prefix) | not)))
        + $new
      )
' "${CONFIG}" > "${TMP}"

jq empty "${TMP}" 2>/dev/null || die "merge produced invalid JSON, config left untouched (backup at ${BACKUP})"

# only write if something actually changed, so re-runs are silent no-ops and
# don't accumulate identical backups
if cmp -s "${CONFIG}" "${TMP}"; then
  info "config already up to date, no changes written"
  rm -f "${BACKUP}"
else
  mv "${TMP}" "${CONFIG}"
  trap - EXIT
  info "backed up previous config to ${BACKUP}"
  ok "merged $(jq '.rules | length' "${RULES_SRC}") rules into the active profile"
fi

# --------------------------------------------------------------------------
# permissions check
#
# The driver extension is the one thing that makes remapping work at all, and
# it is also the one thing no script can turn on.
# --------------------------------------------------------------------------
if systemextensionsctl list 2>/dev/null | grep -i karabiner | grep -q "activated enabled"; then
  ok "driver extension is active - remapping is live"
  info "verify with: karabiner/verify.sh"
else
  echo
  warn "ACTION REQUIRED - these cannot be automated"
  cat <<'EOF'

  1. Launch Karabiner-Elements once (open -a Karabiner-Elements).
     Approve the driver extension when prompted.

  2. System Settings > General > Login Items & Extensions > Driver Extensions
     Enable "Karabiner-VirtualHIDDevice".

  3. System Settings > Privacy & Security > Input Monitoring
     Enable karabiner_grabber and Karabiner-Elements.

  4. Reboot. (Only needed the first time the driver is installed.)

  Then re-run this script to confirm. Open the panes directly with:
    open -a Karabiner-Elements
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"

EOF
fi
