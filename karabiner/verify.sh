#!/usr/bin/env bash
#
# Show what Karabiner is actually running, so "is my remap live?" is one command
# instead of four. Read-only.

set -euo pipefail

CONFIG="${HOME}/.config/karabiner/karabiner.json"
SPEC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/spec.json"

[[ -f "${CONFIG}" ]] || { echo "no ${CONFIG} — run ./install.sh"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found"; exit 1; }

PREFIX="$(jq -r '.prefix // "dotfiles: "' "${SPEC}")"

echo "driver extension:"
if systemextensionsctl list 2>/dev/null | grep -i karabiner | grep -q "activated enabled"; then
  echo "  activated enabled"
else
  echo "  NOT ACTIVE — remapping is dead. See README > Troubleshooting."
fi

echo
echo "karabiner.json:"
if [[ -L "${CONFIG}" ]]; then
  echo "  SYMLINK to $(readlink "${CONFIG}") — should be a real file, re-run ./install.sh"
else
  echo "  real file (correct)"
fi

echo
echo "rules in the selected profile:"
jq -r --arg p "${PREFIX}" '
  .profiles[] | select(.selected)
  | .complex_modifications.rules[]
  | (if (.description // "") | startswith($p) then "  [managed] " else "  [manual]  " end)
    + (.description // "(no description)")
    + "  (" + (.manipulators | length | tostring) + " mappings)"
' "${CONFIG}"

echo
MANAGED=$(jq -r --arg p "${PREFIX}" '
  [.profiles[] | select(.selected) | .complex_modifications.rules[]
   | select((.description // "") | startswith($p))] | length' "${CONFIG}")
EXPECTED=$(jq -r '.groups | length' "${SPEC}")
echo "managed rules: ${MANAGED} live, ${EXPECTED} defined in spec.json"
[[ "${MANAGED}" == "${EXPECTED}" ]] || echo "  MISMATCH — run ./install.sh"
