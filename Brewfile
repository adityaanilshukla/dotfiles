# Brewfile — core tools for this dotfiles setup.
# Install everything with:  brew bundle --file=~/dotfiles/Brewfile
# (install.sh does this for you.)

# ----- Taps -----
tap "nikitabobko/tap"          # aerospace
tap "felixkratz/formulae"      # sketchybar
tap "homebrew-zathura/zathura" # zathura + pdf plugins
tap "tursodatabase/tap"        # turso (online-zathura reading-state sync)

# ----- Window manager + status bar -----
cask "aerospace"
brew "felixkratz/formulae/sketchybar"
cask "font-sketchybar-app-font"      # sketchybar's glyph icons

# ----- Terminal -----
cask "alacritty"

# ----- File manager + fuzzy tooling used by ranger and readbook -----
brew "ranger"
brew "fzf"                            # readbook book picker + ranger
brew "fd"                             # fast file search for ranger

# ----- PDF / eBook reader (zathura) -----
brew "homebrew-zathura/zathura/zathura-pdf-poppler"
brew "homebrew-zathura/zathura/zathura-pdf-mupdf"
brew "tursodatabase/tap/turso"        # online-zathura pulls/pushes reading state
brew "go"                             # builds online-zathura (see install.sh)

# ----- Helpers the tracked configs invoke -----
cask "betterdisplay"                  # sketchybar volume plugin + display scaling
cask "raycast"                        # aerospace alt-d / alt-p bindings
cask "karabiner-elements"             # ctrl+backspace -> forward-delete, etc.

# ----- Fonts -----
cask "font-hack-nerd-font"            # alacritty + sketchybar text font
