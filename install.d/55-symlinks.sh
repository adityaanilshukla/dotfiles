#!/usr/bin/env bash
#
# One job: symlinking configs into place.
#
# Every config this repo owns, linked to where its app expects it.
# Runs BEFORE tmux/alacritty/claude, all of which read a linked file.
set -euo pipefail
# shellcheck source=install.d/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

step "Symlinking configs into place"

# Single-file configs.
files=(
  "zsh/zshrc:$HOME/.zshrc"
  "tmux/tmux.conf:$HOME/.tmux.conf"
  "git/gitconfig:$HOME/.gitconfig"

  # Tailscale host aliases, so `scp file brovo:` works. Inert without the
  # tailscaled daemon: the names in it are MagicDNS names and resolve to
  # nothing until this machine has joined the tailnet.
  "ssh/config:$HOME/.ssh/config"

  # Claude Code notification hook — desktop banner and a sound when a session
  # finishes or needs input. claude/install.sh registers it in settings.json
  # afterwards; the symlink alone does nothing.
  "claude/hooks/notify.sh:$HOME/.claude/hooks/notify.sh"

  # PreToolUse guard: refuses sudo, doas, and osascript's "with administrator
  # privileges" from inside a Claude session, so an escalation has to be typed
  # by a human in a terminal. A guardrail against habit, not a sandbox -- see
  # the header of the script. Registered in settings.json by claude/install.sh.
  "claude/hooks/no-sudo.sh:$HOME/.claude/hooks/no-sudo.sh"
  "alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
  "zathura/zathurarc:$HOME/.config/zathura/zathurarc"

  # Karabiner is deliberately absent here: karabiner.json is generated and
  # merged by karabiner/install.sh, not symlinked. See karabiner/README.md.

  # ~/Scripts is the alt-x launcher's menu: whatever is linked in here is what
  # it offers. Keep that in mind before adding to it.
  "scripts/library:$HOME/Scripts/library"

  # Night Shift toggle. A pass-through to the nightlight CLI from the Brewfile,
  # which exists so the launcher has a file to list; ~/Scripts is not something
  # a brew binary lands in.
  "scripts/nightlight:$HOME/Scripts/nightlight"

  # Keeps the Mac running with the lid shut (a `pmset disablesleep` wrapper with
  # a self-disarming timer), so it can be left locked in a bag and still be
  # reachable. Needs sudo at runtime, not at install time. See scripts/awake.
  "scripts/awake:$HOME/.local/bin/awake"

  # sketchybar-backed countdown timer — see sketchybar/plugins/timer.sh
  "scripts/t:$HOME/.local/bin/t"

  # zathura, privately: open any document with no reading state stored and
  # nothing synced to Turso. Also what library's ctrl-o hands off to.
  "scripts/zp:$HOME/.local/bin/zp"

  # Diagnostic for the one way zathura breaks on its own: its pdf plugins are
  # built from source against whatever mupdf/poppler was installed that day and
  # are never rebuilt on upgrade, so epubs stop opening while pdfs still work.
  # Not in ~/Scripts — it answers a question, it is not a command to run.
  "scripts/check-zathura-plugins:$HOME/.local/bin/check-zathura-plugins"

  # notification dismisser, run by aerospace's alt-shift-x binding
  "scripts/dismiss-notifications:$HOME/Scripts/dismiss-notifications"
  "scripts/notification-center:$HOME/Scripts/notification-center"

  # the alt-x launcher itself. Deliberately NOT in ~/Scripts, or it would list
  # itself in its own menu.
  "scripts/launcher:$HOME/.local/bin/launcher"

  # macOS drag source — ranger's dn binding runs this, since dragon-drop is
  # X11-only. Needs the venv built below.
  "scripts/drag-mac:$HOME/.local/bin/drag-mac"

  # alacritty font size per screen. Run by sketchybar's display_change event
  # (sketchybar/plugins/alacritty-font.sh) and by hand after changing the two
  # sizes inside it. Reads scripts/display-info.swift from beside itself, which
  # is why the link target keeps the same basename.
  "scripts/alacritty-font-size:$HOME/.local/bin/alacritty-font-size"

  # VS Code (macOS config path)
  "vscode/settings.json:$HOME/Library/Application Support/Code/User/settings.json"
  "vscode/keybindings.json:$HOME/Library/Application Support/Code/User/keybindings.json"
)

# Whole-directory symlinks — for multi-file configs. Linked as a single dir so
# new files inside are tracked automatically without touching this list. Only
# use for configs that DON'T write runtime state into their config dir.
dirs=(
  "sketchybar:$HOME/.config/sketchybar"
  "aerospace:$HOME/.config/aerospace"
  "ranger:$HOME/.config/ranger"
)

for pair in "${files[@]}"; do
  src="${pair%%:*}"
  dest="${pair#*:}"
  src_path="$DOTFILES_DIR/$src"

  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mv "$dest" "$dest.backup"
    echo "Backed up $dest to $dest.backup"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -sf "$src_path" "$dest"
  echo "Linked $src_path -> $dest"
done

for pair in "${dirs[@]}"; do
  src="${pair%%:*}"
  dest="${pair#*:}"
  src_path="$DOTFILES_DIR/$src"

  # Back up a real directory; a stale symlink is just replaced.
  if [[ -d "$dest" && ! -L "$dest" ]]; then
    mv "$dest" "$dest.backup"
    echo "Backed up $dest to $dest.backup"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src_path" "$dest"
  echo "Linked $src_path -> $dest"
done
