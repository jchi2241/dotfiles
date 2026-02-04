alias bootstrap="vim ~/.dotfiles/.shell/bootstrap.sh"

# Increase hold down key rate (Linux/X11 only)
[[ "$(uname -s)" == "Linux" ]] && command -v xset &>/dev/null && xset r rate 200 50

# fzf extended regex matchers
export FZF_DEFAULT_OPS="--extended"

# have fzf use ripgrep as the file-searcher with sensible defaults
export FZF_DEFAULT_COMMAND="rg --files --hidden --ignore-file ~/.ignore"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

#go
export PATH=$PATH:/usr/local/go/bin

#neovim
export PATH=$PATH:/usr/local/bin/nvim

