#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

files=(
  "zsh/zshrc:$HOME/.zshrc"
  "tmux/tmux.conf:$HOME/.tmux.conf"
  "git/gitconfig:$HOME/.gitconfig"
  "alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
  "zathura/zathurarc:$HOME/.config/zathura/zathurarc"

  #vscodium
  "VScodium/settings.json:$HOME/.config/VSCodium/User/settings.json"
  "VScodium/keybindings.json:$HOME/.config/VSCodium/User/keybindings.json"
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
