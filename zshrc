export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export PATH=$PATH:/snap/bin

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="igorsilva"
plugins=(git kubectl z)
source $ZSH/oh-my-zsh.sh

# Load pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# fnm
FNM_PATH="/home/jchi/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

# gvm
[[ -s "/home/jchi/.gvm/scripts/gvm" ]] && source "/home/jchi/.gvm/scripts/gvm"
# Load GVM helper functions (fixes "command not found" errors)
[[ -s "$GVM_ROOT/scripts/functions" ]] && source "$GVM_ROOT/scripts/functions"
[[ -s "$GVM_ROOT/scripts/function/_bash_pseudo_hash" ]] && source "$GVM_ROOT/scripts/function/_bash_pseudo_hash"
[[ -s "$GVM_ROOT/scripts/function/_shell_compat" ]] && source "$GVM_ROOT/scripts/function/_shell_compat"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source <(fzf --zsh)

# Added by Nix installer
if [ -e ${HOME}/.nix-profile/etc/profile.d/nix.sh ]; then . ${HOME}/.nix-profile/etc/profile.d/nix.sh; fi

# Source aliases
source ~/.dotfiles/.shell/aliases.sh

# Source bootstrap
source ~/.dotfiles/.shell/bootstrap.sh

# Source work-related bookmarks
source ~/.dotfiles/.shell/work-bookmarks.sh

# Source kubectl auto-completion
source <(kubectl completion zsh)

# Activate direnv
eval "$(direnv hook $SHELL)"

autoload bashcompinit
bashcompinit
# source /home/jchi/projects/vcpkg/scripts/vcpkg_completion.zsh

# Poetry (python dep manager) is installed in /.local/bin
export PATH="/home/jchi/.local/bin:$PATH"

# CLEAN UP
# Fixes error "fsnotify watcher: too many open files"
# sudo sysctl -w fs.inotify.max_user_watches=2099999999
# sudo sysctl -w fs.inotify.max_user_instances=2099999999
# sudo sysctl -w fs.inotify.max_queued_events=2099999999
# source ~/monagent-en


if [ -e /home/jchi/.nix-profile/etc/profile.d/nix.sh ]; then . /home/jchi/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer
