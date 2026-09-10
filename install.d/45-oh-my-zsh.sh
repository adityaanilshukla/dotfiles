#!/usr/bin/env bash
#
# One job: oh my zsh.
#
# MUST run before the symlink step: the installer would otherwise move our
# ~/.zshrc aside and write a stock one in its place.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Oh My Zsh"

# zsh/zshrc sources "$ZSH/oh-my-zsh.sh" unconditionally, so without this a
# fresh machine opens a shell that errors before it draws a prompt. Not from
# brew — the formula was dropped upstream and the install script is what
# ohmyzsh actually supports.
#
# KEEP_ZSHRC=yes is the load-bearing part. The installer's default is to move
# an existing ~/.zshrc aside to ~/.zshrc.pre-oh-my-zsh and write its own
# template in place. Here ~/.zshrc is a symlink into this repo, so the default
# would quietly replace the whole config with a stock one that looks close
# enough to be confusing. Runs before the symlink section for the same reason:
# nothing of ours is in place yet to be clobbered.
#
# RUNZSH=no stops it exec'ing a new interactive zsh and swallowing the rest of
# this script. CHSH=no skips the chsh prompt, which needs a password and has
# nothing to do: zsh is already the macOS default shell.
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "Installing Oh My Zsh..."
  KEEP_ZSHRC=yes RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended \
    || true
  # Checked rather than trusted: a failed `curl` inside the command
  # substitution yields an empty string, so `sh -c ""` exits 0 and the install
  # reads as successful while nothing was installed. The directory is the only
  # honest signal.
  [[ -d "$HOME/.oh-my-zsh" ]] \
    || echo "  Oh My Zsh did not install — zsh will error on every prompt until it does."
fi
