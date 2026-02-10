#!/bin/bash
# install.sh

set -e

DOTFILES_DIR="$HOME/dotfiles"

# List of dotfiles to symlink: [source relative to dotfiles] [target full path]
declare -A files=(
  ["zsh/zshrc"]="$HOME/.zshrc"
  ["tmux/tmux.conf"]="$HOME/.tmux.conf"
  ["fastfetch/config.jsonc"]="$HOME/.config/fastfetch/config.jsonc"
  ["nvim/init.lua"]="$HOME/.config/nvim/init.lua"
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
