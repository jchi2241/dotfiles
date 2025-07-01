alias aliases="vim ~/.dotfiles/.shell/aliases.sh"

alias v='vim'

# ls aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls'

# Aliases to protect against overwriting
alias cp='cp -i'
alias mv='mv -i'

# Update dotfiles
dfu() {
    (
        cd ~/.dotfiles && git pull --ff-only && ./install -q
    )
}

# cd to git root directory
alias cdgr='cd "$(git root)"'

# Git aliases
alias gilo='git log --oneline --graph'
alias gil='git log --graph --abbrev-commit --stat -C --decorate --date=local'
alias gils="git log --graph --abbrev-commit --pretty=format:'%C(red)%h%C(reset) -%C(yellow)%d%C(reset) %s %C(green)(%cr) %C(bold blue)<%an>%C(reset)' -C --decorate --date=local"
alias gis='git status'
alias gid='git diff -C --date=local'
alias giw='git show -C --date=local --decorate'
alias gic='git checkout'
alias gib='git branch'
alias gicm='git commit -m'
alias gicc='git commit -am "CHECKPOINT"'

# Kill port
function kp() {
    fuser -k $1/tcp
}

# Other commands
alias squ="google-chrome https://squoosh.app"
alias open="xdg-open ."
alias ports="lsof -i TCP:9000"
alias copy="xclip -selection c"
alias killchrome="killall chrome"
alias killcontainers='docker rm -f $(docker container ls -aq)'
alias killslack="kill -9 $(pidof slack)"

# Managing dotfiles
alias vimrc="vim ~/.dotfiles/vimrc"
alias initvim="vim ~/.dotfiles/init.vim"
alias zshrc="vim ~/.dotfiles/zshrc"
alias installdotfiles="~/.dotfiles/install"

# Kill and remove all containers
alias drm='docker rm -f $(docker container ls -aq)'
alias dip='docker image prune -a --force'
alias dsp='docker system prune --force --volumes -a'

# Ring
alias loudbell='for i in {1..4}; do paplay /usr/share/sounds/freedesktop/stereo/complete.oga; sleep 0.001; done'

# Clear go cache and builds
alias goclean='go clean -cache -modcache -i -r'

# Kubectl helpers
klog() {
  if [ -z "$1" ]; then
    echo "Usage: klog <deployment-name>"
    return 1
  fi
  pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep "^$1-" | head -n1)
  if [ -z "$pod" ]; then
    echo "No pod found for deployment: $1"
    return 1
  fi
  kubectl logs "$pod"
}
alias klog='klog'

# Learnings
export LEARNS_PATH="~/Documents/learnings"
alias learns="code ${LEARNS_PATH}/stuff-ive-learned.md"
alias learns-commit="cd ${LEARNS_PATH} && gicc"
alias learns-push="cd ${LEARNS_PATH} && git push"
alias learns-pull="cd ${LEARNS_PATH} && git pull"

# Notes
export NOTES_PATH="~/Documents/notes"
alias notes="code ${NOTES_PATH}/notes.md"
alias notes-commit="cd ${NOTES_PATH} && gicc"
alias notes-push="cd ${NOTES_PATH} && git push"
alias notes-pull="cd ${NOTES_PATH} && git pull"

# Sandboxes
alias jss="code ~/Documents/sandbox.js"
alias pys="code ~/Documents/sandbox.py"
alias mds="code ~/Documents/sandbox.md"

alias ucode="sudo apt install code --only-upgrade"
alias uchrome="sudo apt install google-chrome-stable --only-upgrade"

