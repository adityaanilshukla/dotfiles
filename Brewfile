# Brewfile — everything this machine needs, so a fresh Mac is one command.
# Install everything with:  brew bundle --file=~/dotfiles/Brewfile
# (install.sh does this for you.)
#
# To find anything installed here but not tracked below:
#   comm -13 <(grep -oE '"[^"]+"' Brewfile | tr -d '"' | sed 's|.*/||' | sort -u) \
#            <(brew leaves; brew list --cask | sed 's|.*/||' | sort -u)

# ----- Taps -----
tap "nikitabobko/tap"          # aerospace
tap "felixkratz/formulae"      # sketchybar
tap "homebrew-zathura/zathura" # zathura + pdf plugins
tap "tursodatabase/tap"        # turso (online-zathura reading-state sync)
tap "smudge/smudge"            # nightlight

# ----- Window manager + status bar -----
cask "aerospace"
brew "felixkratz/formulae/sketchybar"
cask "font-sketchybar-app-font"      # sketchybar's glyph icons

# ----- Terminal + shell -----
cask "alacritty"
brew "tmux"                          # tmux.conf is symlinked; inert without this
brew "zsh-autosuggestions"           # sourced by zshrc
brew "zsh-syntax-highlighting"       # sourced by zshrc, must load last
brew "bash"                          # newer than the bash macOS ships
brew "fastfetch"                     # zshrc alias f

# ----- Editor -----
# nvim itself is NOT a formula. bob manages the Neovim version and puts the
# binary in ~/.local/share/bob/nvim-bin, which zshrc adds to PATH. Installing
# bob alone leaves that directory empty, so install.sh runs `bob use` after.
brew "bob"
brew "tree-sitter"
brew "tree-sitter-cli"
brew "tree-sitter@0.25"
brew "ripgrep"                       # telescope / live grep
brew "pyright"                       # LSP: python
brew "lua-language-server"           # LSP: lua
brew "marksman"                      # LSP: markdown
brew "ltex-ls-plus"                  # LSP: prose and grammar
brew "ruff"                          # python lint + format
brew "stylua"                        # lua format
brew "luacheck"                      # lua lint
brew "shellcheck"                    # shell lint
brew "yamllint"                      # yaml lint
brew "golangci-lint"                 # go lint

# ----- File manager + fuzzy tooling used by ranger and readbook -----
brew "ranger"
# Declared explicitly rather than relied on as ranger's transitive dep: the
# drag-mac venv (see install.sh) needs a python3 that is actually guaranteed
# to be here.
brew "python"
brew "fzf"                            # readbook book picker + ranger
brew "fd"                             # fast file search for ranger
brew "trash-cli"                      # ranger's dT binding (rc.conf); keg-only, zshrc puts it on PATH
brew "bat"                            # cat with highlighting
brew "tree"
brew "dysk"                           # disk usage
brew "tldr"

# ----- Git -----
brew "gh"                             # PRs from the terminal
brew "lazygit"

# ----- PDF / eBook reader (zathura) -----
# Named explicitly rather than left to arrive as a dependency of the pdf
# plugins below: depending on someone else's dependency graph is how a thing
# quietly stops being installed.
brew "zathura"
brew "homebrew-zathura/zathura/zathura-pdf-poppler"
brew "homebrew-zathura/zathura/zathura-pdf-mupdf"
brew "tursodatabase/tap/turso"        # online-zathura pulls/pushes reading state
brew "go"                             # builds online-zathura (see install.sh)
cask "xournal++"                      # annotating PDFs

# ----- Documents + media -----
brew "pandoc"
brew "weasyprint"                     # html to pdf
brew "imagemagick"
brew "mpv"                            # ranger rifle.conf video rule
brew "sphinx-doc"

# ----- Browsers -----
cask "brave-browser"                  # aerospace alt-f / ctrl-shift-p, ranger PDF opener
cask "firefox"

# ----- Languages, build tooling, data -----
cask "miniconda"                      # zshrc has a conda init block for this path
brew "uv"                             # python package manager
brew "pipx"
brew "python-tk@3.14"
brew "pyqt"
brew "pyvim"
brew "cmake"
brew "meson"
brew "pkgconf"
brew "mysql"
brew "bats-core"                      # bash test runner

# ----- Local models -----
brew "ollama"
brew "llama.cpp"

# ----- Editors and dev apps -----
cask "visual-studio-code"             # install.sh installs its extensions
cask "claude-code"

# ----- Helpers the tracked configs invoke -----
# The fast path in sketchybar's audio-sink plugin. `SwitchAudioSource -c` reads
# the current output device in ~20ms, against ~130ms for system_profiler, which
# is what lets that module poll every second. Optional: the plugin falls back to
# system_profiler alone if this is missing, just with a laggier glyph.
brew "switchaudio-osx"                # sketchybar audio-sink plugin fast path

cask "betterdisplay"                  # sketchybar volume plugin + display scaling
cask "raycast"                        # aerospace alt-d / alt-p bindings
cask "karabiner-elements"             # keyboard remaps; see karabiner/README.md
brew "jq"                             # karabiner/install.sh merges rules with it
                                      # (macOS ships /usr/bin/jq, but don't rely
                                      #  on a version Apple controls)
cask "keyclu"                         # shortcut cheatsheet
cask "scroll-reverser"                # separate scroll direction for mouse vs trackpad
brew "smudge/smudge/nightlight"       # night shift from the CLI
cask "macfuse"                        # needs manual kernel-extension approval + reboot

# ----- Networking + sync -----
brew "syncthing"
brew "tailscale"                      # links this machine to brovo
cask "localsend"

# ----- Comms + everyday apps -----
cask "spotify"
cask "telegram"
cask "whatsapp"                       # ranger's dn drops files into it
cask "zoom"
cask "microsoft-teams"
cask "microsoft-outlook"
cask "microsoft-word"
cask "zoho-cliq"
cask "zoho-mail"
cask "anki"

# ----- Fonts -----
cask "font-hack-nerd-font"            # alacritty + sketchybar text font

# Deliberately NOT tracked: qbittorrent. install.sh still de-quarantines it if
# you install it by hand, since its cask build is ad-hoc signed.
