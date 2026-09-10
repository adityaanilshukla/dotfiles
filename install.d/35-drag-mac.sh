#!/usr/bin/env bash
#
# One job: drag-mac venv.
#
# PyObjC drag source behind ranger's dn binding. Needs its own venv.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "drag-mac venv"

# PyObjC drag source behind ranger's dn binding. Homebrew's python3 is PEP 668
# externally managed, so pip refuses to install into it and PyObjC has to live
# in a venv. Idempotent: re-running only upgrades what's already there.
DRAG_MAC_VENV="$HOME/.local/share/drag-mac/venv"
if [[ "$(uname -s)" == "Darwin" ]]; then
  # Test what the venv can actually do, not whether its directory exists. A venv
  # keeps working only as long as the python it was built against stays put, so
  # a Homebrew python upgrade silently breaks it. Importing the frameworks the
  # tool really uses is the only check that catches that, and it makes this
  # block self-healing on every run.
  if ! "$DRAG_MAC_VENV/bin/python3" -c "import objc, AppKit, Quartz" >/dev/null 2>&1; then
    echo "Building drag-mac venv..."
    # :? so an unset or empty variable aborts instead of expanding to something
    # catastrophic.
    rm -rf "${DRAG_MAC_VENV:?refusing to remove an empty path}"
    # Delegated to the Makefile on purpose: it already owns the dependency list,
    # and duplicating it here is how the two drift. They did, briefly, and
    # `make test` then failed on a fresh machine for want of pytest.
    if make -C "$DOTFILES_DIR/drag-mac" venv >/dev/null; then
      echo "  drag-mac venv built"
    else
      echo "  drag-mac venv FAILED — dn will report it. Retry: make -C '$DOTFILES_DIR/drag-mac' venv"
    fi
  fi

  # Prove it end to end rather than assuming, so a broken install is loud here
  # instead of showing up later as dn appearing to do nothing.
  if "$DRAG_MAC_VENV/bin/python3" "$DOTFILES_DIR/drag-mac/drag_mac.py" >/dev/null 2>&1; then
    echo "  drag-mac self-test unexpectedly passed with no arguments"
  elif [[ $? -eq 2 ]]; then
    echo "  drag-mac ready"
  else
    echo "  drag-mac self-test FAILED — check 'make -C $DOTFILES_DIR/drag-mac test'"
  fi
fi
