#!/usr/bin/env bash
#
# One job: ssh directory permissions.
#
# ssh refuses to run rather than degrade, so the modes must be exact.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "SSH directory permissions"

# ssh/config is symlinked below like any other config, but two things about it
# cannot be expressed in a symlink.
#
# ssh enforces permissions itself and refuses to run rather than degrade: it
# ignores a config file others can write, and it will not use a ControlPath in
# a directory others can enter. A fresh ~/.ssh created by `mkdir -p` in the
# symlink loop is 755, which fails both tests, so set the modes explicitly.
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh" "$HOME/.ssh/sockets"
