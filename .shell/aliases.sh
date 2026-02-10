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
alias gic='git checkout'
alias gib='git branch'
alias gibs='(echo " |BRANCH|MESSAGE|UPDATED"; git for-each-ref --sort=committerdate refs/heads/ --format="%(if)%(HEAD)%(then)*%(else) %(end)|%(refname:short)|%(subject)|%(committerdate:relative)") | column -t -s"|" | awk "BEGIN{GRN=sprintf(\"%c[1;32m\",27);RST=sprintf(\"%c[0m\",27)} NR==1{print;next} \$1==\"*\"{print GRN \$0 RST; next} {print}"'
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
alias cc="claude"
alias ccd="claude --dangerously-skip-permissions"

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
  if [ $# -lt 1 ]; then
    echo "Usage: klog <deployment-name> [-f] [kubectl logs args...]"
    return 1
  fi

  local dep="$1"
  shift
  local mode="tail"
  local passthrough=()

  # Detect -f in args
  for arg in "$@"; do
    if [ "$arg" = "-f" ]; then
      mode="follow"
    else
      passthrough+=("$arg")
    fi
  done

  if kubectl get pods -l app.kubernetes.io/component="$dep" "${passthrough[@]}" 2>/dev/null | grep -q .; then
    if [ "$mode" = "follow" ]; then
      kubectl logs -l app.kubernetes.io/component="$dep" --all-containers=true -f "${passthrough[@]}"
    else
      kubectl logs -l app.kubernetes.io/component="$dep" --all-containers=true --tail=-1 "${passthrough[@]}"
    fi
    return $?
  fi

  if kubectl get pods -l run="$dep" "${passthrough[@]}" 2>/dev/null | grep -q .; then
    if [ "$mode" = "follow" ]; then
      kubectl logs -l run="$dep" --all-containers=true -f "${passthrough[@]}"
    else
      kubectl logs -l run="$dep" --all-containers=true --tail=-1 "${passthrough[@]}"
    fi
    return $?
  fi

  echo "No pods found with label app.kubernetes.io/component=$dep or run=$dep"
  return 1
}

# Toggle res
alias toggleres="~/.local/bin/toggle-res.sh"

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

# Git worktree helpers
# worktree-add <branch> [base] - create worktree with new branch
# worktree-cd <branch>         - cd into existing worktree
# worktree-rm <branch>         - remove worktree and delete branch
# worktree-ls                  - list all worktrees
worktree-add() {
  if [ $# -lt 1 ]; then
    echo "Usage: worktree-add <branch-name> [base-branch]"
    echo "  Creates a new worktree with a new branch"
    echo "  Example: worktree-add chi/feature-x"
    echo "  Example: worktree-add chi/feature-x origin/master"
    return 1
  fi

  local branch="$1"
  local base="${2:-HEAD}"
  local main_repo
  main_repo="$(git rev-parse --show-toplevel)"
  local repo_name=$(basename "$main_repo")
  local dir_name="${branch//\//-}"  # replace slashes with dashes
  local worktree_path="../${repo_name}-${dir_name}"

  git worktree add "$worktree_path" -b "$branch" "$base" && \
    echo "Created worktree at $worktree_path" && \
    cd "$worktree_path" || return 1

  # Symlink files that are generated locally and not tracked by git,
  # so the worktree doesn't end up with stale copies.
  if [ -f "$main_repo/test/kubeconfig.yml" ]; then
    mkdir -p test
    ln -sf "$main_repo/test/kubeconfig.yml" test/kubeconfig.yml
    echo "Symlinked test/kubeconfig.yml from main repo"
  fi
}

# Remove worktree and its branch
worktree-rm() {
  if [ $# -lt 1 ]; then
    echo "Usage: worktree-rm <branch-name>"
    echo "  Removes the worktree and deletes the branch"
    echo "  Example: worktree-rm chi/feature-x"
    return 1
  fi

  local branch="$1"
  local repo_name=$(basename "$(git rev-parse --show-toplevel)")
  local dir_name="${branch//\//-}"
  local worktree_path="../${repo_name}-${dir_name}"

  if [ ! -d "$worktree_path" ]; then
    echo "Worktree not found at $worktree_path"
    echo "Available worktrees:"
    git worktree list
    return 1
  fi

  git worktree remove "$worktree_path" && \
    git branch -d "$branch" && \
    echo "Removed worktree and branch: $branch"
}

# List worktrees
alias worktree-ls='git worktree list'

# Short aliases for worktree commands
alias wta='worktree-add'
alias wtl='worktree-ls'
alias wtr='worktree-rm'
alias wtc='worktree-cd'

# cd into an existing worktree
worktree-cd() {
  if [ $# -lt 1 ]; then
    echo "Usage: worktree-cd <branch-name>"
    echo "  cd into an existing worktree"
    echo "Available worktrees:"
    git worktree list
    return 1
  fi

  local branch="$1"
  local worktree_path=$(git worktree list --porcelain | grep -B2 "branch refs/heads/$branch$" | grep '^worktree' | sed 's/^worktree //')

  if [ -z "$worktree_path" ]; then
    echo "No worktree found for branch: $branch"
    echo "Available worktrees:"
    git worktree list
    return 1
  fi

  cd "$worktree_path"
}

# Zsh completions for worktree commands
if [ -n "$ZSH_VERSION" ]; then
  _worktree-rm() {
    local worktree_branches
    worktree_branches=($(git worktree list --porcelain 2>/dev/null | grep '^branch' | sed 's|branch refs/heads/||'))
    _describe 'worktree branch' worktree_branches
  }
  compdef _worktree-rm worktree-rm
  compdef _worktree-rm worktree-cd

  _worktree-add() {
    if [ "$CURRENT" -eq 3 ]; then
      # Second arg: complete to branches (for base)
      local branches
      branches=($(git branch -a --format='%(refname:short)' 2>/dev/null))
      _describe 'base branch' branches
    fi
  }
  compdef _worktree-add worktree-add

  # Completions for short aliases
  compdef _worktree-cd wtc
  compdef _worktree-rm wtr
  compdef _worktree-add wta
fi

