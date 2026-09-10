#!/usr/bin/env bash
#
# One job: homebrew + brewfile packages.
#
# Install Homebrew if missing, then every app/tool from the Brewfile.
# Runs first: almost every later step is guarded on a binary from here.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Homebrew + Brewfile packages"

# Install Homebrew if missing, then install every app/tool from the Brewfile.
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for the rest of this script (Apple Silicon vs Intel).
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

BREW_BUNDLE_INCOMPLETE=0
if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
  echo "Installing packages from Brewfile..."
  # Don't abort the whole setup if a single cask needs a password/retry.
  brew bundle --file="$DOTFILES_DIR/Brewfile" \
    || echo "brew bundle finished with some failures — retrying once."

  # One retry, because the common failure is transient: a cask that wanted a
  # password, or a tap that had not finished syncing when its formula was
  # first reached.
  if ! brew bundle check --file="$DOTFILES_DIR/Brewfile" >/dev/null 2>&1; then
    brew bundle --file="$DOTFILES_DIR/Brewfile" >/dev/null 2>&1 || true
  fi

  # Then say plainly what is still missing, because everything downstream is
  # guarded on these existing and will otherwise skip in silence. Observed:
  # sketchybar failed here, arrived half an hour later by hand, and the service
  # step had already run and quietly skipped it — leaving a fully configured
  # bar that never appeared on screen, with the install reporting success.
  if ! brew bundle check --file="$DOTFILES_DIR/Brewfile" >/dev/null 2>&1; then
    BREW_BUNDLE_INCOMPLETE=1
    echo
    echo "!! brew bundle check reports unsatisfied dependencies:"
    # 2>&1, not 2>/dev/null: `check --verbose` writes the list to stderr, so
    # discarding stderr discards the entire point of running it.
    brew bundle check --file="$DOTFILES_DIR/Brewfile" --verbose 2>&1 \
      | sed 's/^/     /'
    echo
    echo "   On a fresh machine these really are missing, and anything below"
    echo "   that depends on them will skip and say so."
    echo
    echo "   On an established machine, expect false alarms: an app installed"
    echo "   by hand is not brew-managed, so it reads as missing while being"
    echo "   perfectly present. Hand ownership over with:"
    echo "     brew install --cask --adopt <name>"
  fi
fi

if [[ "$BREW_BUNDLE_INCOMPLETE" -eq 1 ]]; then
  echo
  echo "Finished, but brew bundle check was not clean — see the list above."
  echo "If those are genuinely missing, install them and re-run this script;"
  echo "it is idempotent. If they were installed by hand, they are fine."
fi
