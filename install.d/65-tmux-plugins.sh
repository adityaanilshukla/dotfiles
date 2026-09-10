#!/usr/bin/env bash
#
# One job: tmux plugins (tpm).
#
# Runs AFTER 55-symlinks: install_plugins needs a tmux server that has
# already sourced ~/.tmux.conf, and that file is a symlink this repo owns.
# In the single-file installer this ran BEFORE the links were made, so on a
# fresh machine the source-file failed into `|| true` and tpm installed
# nothing -- the exact failure its own comment warned about.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "tmux plugins (tpm)"

# tmux.conf declares tmux-resurrect and tmux-continuum, but tpm is what
# actually fetches them and tpm is not a brew formula. Without this block the
# @plugin lines are inert: the config loads clean and silently does nothing,
# which is exactly how resurrect sat dead on this machine.
#
# Must run after the symlink section, because install_plugins needs a tmux
# server that has already sourced ~/.tmux.conf. On a fresh machine there is no
# server yet, so start a throwaway session and tear it down afterwards.
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
  echo "Cloning tpm..."
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR" \
    || echo "  tpm clone failed - install manually: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
fi
if [[ -d "$TPM_DIR" ]] && command -v tmux >/dev/null 2>&1; then
  TPM_TEMP_SESSION=""
  if ! tmux has-session 2>/dev/null; then
    tmux new-session -d -s tpm-install 2>/dev/null && TPM_TEMP_SESSION="tpm-install"
  fi
  tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 || true
  if "$TPM_DIR/bin/install_plugins" >/dev/null 2>&1; then
    echo "tmux plugins installed."
  else
    echo "  tpm install_plugins failed - run prefix + I inside tmux."
  fi
  [[ -n "$TPM_TEMP_SESSION" ]] && tmux kill-session -t "$TPM_TEMP_SESSION" 2>/dev/null
fi
