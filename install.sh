#!/bin/bash
# install.sh

set -e

DOTFILES_DIR="$HOME/dotfiles"

# List of dotfiles to symlink: [source relative to dotfiles] [target full path]
declare -A files=(
  ["zsh/.zshrc"]="$HOME/.zshrc"
  ["tmux/.tmux.conf"]="$HOME/.tmux.conf"
  ["x/.Xresources"]="$HOME/.Xresources"
  ["x/.xprofile"]="$HOME/.xprofile"
  ["gtk/.config/gtk-3.0/settings.ini"]="$HOME/.config/gtk-3.0/settings.ini"
  ["gtk/.config/gtk-4.0/settings.ini"]="$HOME/.config/gtk-4.0/settings.ini"
  ["dunst/dunstrc"]="$HOME/.config/dunst/dunstrc"
  ["desktop/shutdown.desktop"]="$HOME/.local/share/applications/shutdown.desktop"
)

for src in "${!files[@]}"; do
  dest="${files[$src]}"
  src_path="$DOTFILES_DIR/$src"

  # Backup if file already exists and is not a symlink
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.backup"
    echo "Backed up $dest to $dest.backup"
  fi

  # Ensure parent directory exists
  mkdir -p "$(dirname "$dest")"

  # Create symlink
  ln -sf "$src_path" "$dest"
  echo "Linked $src_path -> $dest"
done
