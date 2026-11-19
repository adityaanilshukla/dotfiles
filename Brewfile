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
# alacritty is NOT installed from here. Homebrew disabled the cask on
# 2026-09-01 because the upstream build stopped passing the macOS Gatekeeper
# check, so `brew install --cask alacritty` now errors out and `brew bundle`
# fails on this line if it is uncommented. Download the .dmg from
# github.com/alacritty/alacritty/releases and drag it to /Applications.
#
# Consequence worth knowing, because it silently breaks keybindings: a
# hand-installed .app puts no `alacritty` binary on PATH, unlike the cask which
# linked one into the brew prefix. Anything spawning a terminal has to go
# through `open -na Alacritty` instead. See the alt-x and alt-n bindings in
# aerospace/aerospace.toml, which do exactly that.
# cask "alacritty"
brew "tmux"                          # tmux.conf is symlinked; inert without this
brew "zsh-autosuggestions"           # sourced by zshrc
brew "zsh-syntax-highlighting"       # sourced by zshrc, must load last
brew "bash"                          # newer than the bash macOS ships
brew "fastfetch"                     # zshrc alias f
brew "htop"                           # process viewer
brew "wget"

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
brew "bash-language-server"           # LSP: bash
brew "typescript-language-server"     # LSP: js / ts
brew "jdtls"                          # LSP: java
brew "ruff"                          # python lint + format
brew "stylua"                        # lua format
brew "luacheck"                      # lua lint
brew "shellcheck"                    # shell lint
brew "yamllint"                      # yaml lint
brew "golangci-lint"                 # go lint
brew "checkstyle"                     # java lint

# conform.nvim formatters. These are named in nvim's plugin_config/conform.lua,
# which now resolves each one per buffer and silently skips what is not
# installed -- so a missing binary here is not an error any more, it is just a
# filetype that quietly stops being formatted. Tracked so brew bundle restores
# them rather than leaving that to be noticed months later.
brew "black"                         # python format
brew "isort"                         # python import sort
brew "shfmt"                         # shell format
brew "taplo"                         # toml format
brew "clang-format"                  # c / c++ format
brew "google-java-format"            # java format

# ----- File manager + fuzzy tooling used by ranger and library -----
brew "ranger"
# Declared explicitly rather than relied on as ranger's transitive dep: the
# drag-mac venv (see install.sh) needs a python3 that is actually guaranteed
# to be here.
brew "python"
brew "fzf"                            # alt-x launcher menu, library picker, ranger
brew "fd"                             # fast file search for ranger
brew "trash-cli"                      # ranger's dT binding (rc.conf); keg-only, zshrc puts it on PATH
brew "bat"                            # cat with highlighting
brew "tree"
brew "dysk"                           # disk usage
brew "tlrc"                           # the `tldr` command. Homebrew dropped the
                                      # `tldr` formula; tlrc is the official
                                      # client that replaced it

# ----- Git -----
brew "gh"                             # PRs from the terminal
brew "lazygit"

# ----- PDF / eBook reader (zathura) -----
# Named explicitly rather than left to arrive as a dependency of the pdf
# plugins below: depending on someone else's dependency graph is how a thing
# quietly stops being installed.
brew "zathura"
# Both plugins are source-only in this tap: no bottle, so brew compiles them
# against whatever mupdf/poppler is installed at the time. It does NOT rebuild
# them when those upgrade, and there is no revision bump to force it either, so
# the plugin quietly keeps a stale header version. mupdf notices and refuses
# ("cannot create context: incompatible header (1.28.2) and library (1.28.3)
# versions" -> "could not open document"); poppler usually keeps linking, so it
# breaks later and less obviously.
#
# Both of these are the FALLBACK renderer now. A machine that has been through
# `scripts/build-zathura-gtk4` runs the GTK4 zathura out of ~/.local, which
# carries its own mupdf plugin and never looks here; zsh/zshrc unsets
# ZATHURA_PLUGINS_PATH entirely on that path. These two matter on a machine that
# has not had that build -- ello, a fresh laptop -- where the GTK3 zathura from
# the tap is what opens documents.
#
# On that fallback path both plugins claim PDF and the first entry in
# ZATHURA_PLUGINS_PATH wins, which zsh/zshrc orders mupdf-first because poppler
# is ~30x slower per page, felt at page boundaries and on zoom. That makes a
# drifted mupdf total rather than partial there: it still claims PDF, then
# refuses to open anything, and poppler cannot step in because registration
# already happened. Nothing opening at all is the tell.
# `scripts/check-zathura-plugins` names the drift; the fix is
#   brew reinstall --build-from-source zathura-pdf-mupdf zathura-pdf-poppler
#
# poppler stays installed only as a hedge: it is one line in zshrc to put it
# back in front if some PDF turns out to render wrong under mupdf.
brew "homebrew-zathura/zathura/zathura-pdf-poppler"
brew "homebrew-zathura/zathura/zathura-pdf-mupdf"
brew "tursodatabase/tap/turso"        # online-zathura pulls/pushes reading state
brew "go"                             # builds online-zathura (see install.sh)

# ----- Documents + media -----
# sphinx-doc was removed on 2026-09-30 as unreferenced and has stayed gone.
# pandoc went with it on the same grounds and then came back on 2026-11-17 --
# not drift: the nvim repo's readme installs it alongside weasyprint and biber
# for document conversion. Tracked here so the two repos stop disagreeing.
brew "pandoc"                         # nvim readme installs it with weasyprint
brew "weasyprint"                     # html to pdf
brew "imagemagick"
brew "mpv"                            # ranger rifle.conf video rule

# ----- Browsers -----
cask "brave-browser"                  # aerospace alt-f / ctrl-shift-p, ranger PDF opener
cask "firefox"
cask "google-chrome"                  # the third browser; see also scripts/leetcode-cookie,
                                      # which reads Firefox's jar specifically

# ----- Languages, build tooling, data -----
# Removed on 2026-09-30, all unreferenced and undepended-on: mysql (296MB),
# pyvim (a Python reimplementation of vim, alongside a real Neovim setup),
# and pyqt -- which was 41MB itself and dragged 640MB of Qt behind it.
cask "miniconda"                      # zshrc has a conda init block for this path
brew "uv"                             # python package manager
brew "pipx"
brew "python-tk@3.14"
brew "cmake"
brew "meson"
brew "pkgconf"
brew "bats-core"                      # bash test runner
brew "pnpm"                           # node package manager
brew "python@3.11"
brew "postgresql@17", link: true      # versioned formulae are keg-only by
                                      # default; this one is linked, and
                                      # saying so keeps `bundle check` quiet
brew "opam"                           # ocaml package manager

# ----- Cloud + infra CLIs -----
brew "awscli"
brew "flyctl"
brew "opentofu"
brew "powershell"
# azure-cli is a cask here, not a formula, and the distinction matters. It was
# installed as a formula until 2026-11-19; homebrew-core has since dropped that
# formula and only the cask remains. An installed formula whose name no longer
# resolves makes `brew bundle cleanup` abort outright, which is how this was
# found -- so if az ever needs reinstalling, reach for the cask.
cask "azure-cli"

# ----- Local models -----
brew "ollama"
brew "llama.cpp"

# Audio deps for the VoiceMode Claude Code plugin, which runs Whisper (STT) and
# Kokoro (TTS) locally -- no cloud API. The plugin itself lives in ~/.claude and
# is not tracked here, but it is dead without these two: ffmpeg does the capture
# and resampling, portaudio is the device layer the Python bindings open the mic
# through. Tracked because a fresh Mac has neither, and the failure is a plugin
# that installs cleanly and then cannot hear anything.
#
# The model is pinned separately, outside this repo, in
# ~/.voicemode/voicemode.env -- VOICEMODE_WHISPER_MODEL=base, ~500 MB resident,
# which is the size that makes sense on 16 GB.
brew "ffmpeg"
brew "portaudio"

# ----- Editors and dev apps -----
cask "visual-studio-code"             # install.sh installs its extensions
cask "claude-code"
cask "obsidian"
cask "orbstack"                       # docker + linux VMs

# ----- Helpers the tracked configs invoke -----
# The fast path in sketchybar's audio-sink plugin. `SwitchAudioSource -c` reads
# the current output device in ~20ms, against ~130ms for system_profiler, which
# is what lets that module poll every second. Optional: the plugin falls back to
# system_profiler alone if this is missing, just with a laggier glyph.
brew "switchaudio-osx"                # sketchybar audio-sink plugin fast path

# claude/hooks/notify.sh posts its banner with this. It was installed by hand
# and missing from here, so a fresh machine ran the hook and got nothing.
brew "terminal-notifier"              # claude/hooks/notify.sh

cask "betterdisplay"                  # sketchybar volume plugin + display scaling
cask "raycast"                        # aerospace alt-d / alt-p bindings
cask "karabiner-elements"             # keyboard remaps; see karabiner/README.md
brew "jq"                             # karabiner/install.sh merges rules with it
                                      # (macOS ships /usr/bin/jq, but don't rely
                                      #  on a version Apple controls)
cask "keyclu"                         # shortcut cheatsheet
cask "scroll-reverser"                # separate scroll direction for mouse vs trackpad
brew "smudge/smudge/nightlight"       # night shift from the CLI

# Moves the cursor from the command line. scripts/mouse-jiggle nudges it one
# pixel and back every two minutes so this Mac reads as present rather than
# idle, run at login by launchd/com.aditya.dotfiles.mouse-jiggle.plist.
#
# Not interchangeable with caffeinate, which is the tool people reach for
# first: caffeinate stops the machine sleeping but leaves HIDIdleTime climbing,
# and HIDIdleTime is the number Teams and Slack read to decide you are away.
# Only a real or synthetic input event resets it.
# Installed everywhere, used only where the jiggler is switched on: a Brewfile
# has no per-machine mechanism, and 2MB on the machines that never call it is
# cheaper than a second Brewfile. The switch itself is machines/<host>.conf.
brew "cliclick"                       # scripts/mouse-jiggle moves the cursor with it

brew "scrcpy"                         # phone mirroring. The aspect-locked window
                                      # scripts/center-window was written for,
                                      # and documents at length.
cask "android-platform-tools"         # adb, which scrcpy drives

# ----- Networking + sync -----
brew "syncthing"
brew "tailscale"                      # joins the tailnet: brovo, kalu, buffyx, ello.
                                      # CLI only — the daemon needs
                                      # `sudo brew services start tailscale`, see BOOTSTRAP.md
cask "localsend"

# ----- Comms + everyday apps -----
cask "spotify"
cask "telegram"
cask "whatsapp"                       # ranger's dn drops files into it
cask "zoom"
cask "microsoft-teams"
cask "microsoft-outlook"              # the work mail; sketchybar's M counts its
                                      # Dock badge -- see sketchybar/plugins/unread.sh
cask "microsoft-word"
cask "microsoft-excel"
cask "microsoft-powerpoint"
# Both Zoho apps are deliberately absent: the work mail migrated to Outlook and
# the chat is no longer used. Uninstalled everywhere on 2026-09-30.
cask "anki"
cask "wispr-flow"                     # dictation; push-to-talk needs the F13
                                      # rule in karabiner/spec.json and
                                      # AppleFnUsageType in macos/defaults.sh

# ----- Fonts -----
cask "font-hack-nerd-font"            # alacritty + sketchybar text font

# ----- Installed on request, with no consumer in these configs -----
# Everything above earns its place: some file in this repo or the nvim one calls
# it. These do not. They were each installed deliberately (on request, not as
# somebody's dependency), nothing installed depends on them, and a grep across
# both repos finds no reference. They are tracked so a rebuild is faithful to
# the machine, not because anything here needs them -- which makes this the
# list to prune first if any turn out to be leftovers.
brew "dockutil"                       # scripted Dock changes
brew "espeak-ng"                      # text-to-speech engine
brew "gsl"                            # GNU Scientific Library
brew "qalculate-qt"                   # calculator
brew "qpdf"                           # pdf page + metadata surgery
brew "sentencepiece"                  # tokenizer library
brew "sevenzip"                       # 7z archives
cask "keyboardcleantool"              # blocks every key so the keyboard can be wiped

# Deliberately NOT tracked: gtk4 and graphene. They arrive as dependencies of
# scripts/build-zathura-gtk4, which compiles zathura from source into
# ~/.local/zathura-gtk4 and is optional by design (see BOOTSTRAP.md). Because
# nothing here declares them, `brew bundle cleanup` lists both for removal --
# taking them would leave the GTK4 zathura built but unable to start, and the
# fallbacks in zshrc, scripts/zp and scripts/library would quietly go back to
# the jittery GTK3 brew build. Do not let cleanup have them.
#
# Deliberately NOT tracked: qbittorrent. install.sh still de-quarantines it if
# you install it by hand, since its cask build is ad-hoc signed.
