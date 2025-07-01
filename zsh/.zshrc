# Minimal .zshrc setup

# Enable history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt inc_append_history
setopt share_history

# Prompt
PROMPT='%F{cyan}%n@%m%f %F{yellow}%~%f %# '

# Aliases
alias n='nvim'
alias c='clear'
alias rr='ranger'

# Enable completion
autoload -Uz compinit
compinit

# Enable syntax highlighting (if installed)
if type zsh-syntax-highlighting &>/dev/null; then
  source $(dirname $(which zsh-syntax-highlighting))/zsh-syntax-highlighting.zsh
fi

# Source user scripts
[ -f ~/.zsh_aliases ] && source ~/.zsh_aliases
