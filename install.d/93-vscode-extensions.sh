#!/usr/bin/env bash
#
# One job: vs code extensions.
#
# From vscode/extensions.txt, via the code CLI.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "VS Code extensions"

# Resolve the `code` CLI even if it isn't on PATH yet (fresh install).
CODE_BIN="$(command -v code || true)"
if [[ -z "$CODE_BIN" ]]; then
  app_cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  [[ -x "$app_cli" ]] && CODE_BIN="$app_cli"
fi

ext_list="$DOTFILES_DIR/vscode/extensions.txt"
if [[ -z "$CODE_BIN" ]]; then
  echo "VS Code 'code' CLI not found — install VS Code, then re-run this script to add extensions."
elif [[ -f "$ext_list" ]]; then
  echo "Installing VS Code extensions..."
  while IFS= read -r ext; do
    ext="${ext%%#*}"                       # strip inline comments
    ext="$(echo "$ext" | tr -d '[:space:]')"  # trim whitespace
    [[ -z "$ext" ]] && continue
    "$CODE_BIN" --install-extension "$ext" --force
  done < "$ext_list"
fi
