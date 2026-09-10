#!/usr/bin/env bash
#
# One job: de-quarantining ad-hoc-signed casks.
#
# Strip the Gatekeeper quarantine flag from casks that are ad-hoc signed
# rather than notarized, so they open without a "could not verify" prompt.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "De-quarantining ad-hoc-signed casks"

# qBittorrent's cask build is ad-hoc signed (not notarized), so Gatekeeper
# quarantines it and blocks first launch. Strip the quarantine flag so it opens
# without the "could not verify" prompt. Re-runs harmlessly if already clear.
# shellcheck disable=SC2043  # a one-entry list on purpose: it exists to grow
for app in "/Applications/qBittorrent.app"; do
  [[ -d "$app" ]] && xattr -dr com.apple.quarantine "$app" 2>/dev/null || true
done
