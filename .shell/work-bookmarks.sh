alias wb="vim /home/jchi/.dotfiles/.shell/work-bookmarks.sh"

# Bookmarks
alias proj='cd ~/projects'
alias docs='cd ~/projects/docs'
alias studio='cd ~/projects/memsql/go/src/platform/studio'
alias bf='cd ~/projects/bifrost'
alias elq='cd ~/projects/eloqua'
alias blog='cd ~/projects/blog'
alias hel='cd ~/projects/helios'

# Bifrost commands
alias rbf='bf && make start-frontend'
alias bbf='bf && make build-frontend'
alias sbf="bf && make server"

# Helios commands
alias lhel="kcadm-login && kcadm update realms/memsql -s verifyEmail=false"
alias rkct="./deploy/kube/util/reload-keycloak-img.sh && ./deploy/kube/util/reset-postgres.sh"
alias login-ecr="cd ~/projects/aws-ci-runners && make login-registry && cd -"
alias login-cc="cd ~ && aws sso login --profile=EngAIDevUser-651246146166 && cd -"
alias nukedocker='
  [ "$(docker ps -q)" ] && docker stop $(docker ps -q);
  [ "$(docker ps -aq)" ] && docker rm $(docker ps -aq);
  [ "$(docker volume ls -q)" ] && docker volume rm $(docker volume ls -q)
'
alias nukehelios="hel && nukedocker && rm -rf singlestore.com/helios/bin && cd singlestore.com/helios && goclean"
alias init-analyst="NOVA=1 SINGLESTORE_NEXUS=/home/jchi/projects/singlestore-nexus make kube-init && make start-nova-workspace && make setup-analyst && make frontend-start"

# Test example commands
# Reminders
# - Run a single test, add env GO_TEST_VERBOSE='-v -run <TestName>'
# - Run a single package, add env BACKEND_TEST=<package>'.
#   Package is full path if cluster-test, else, it's the path after singlestore.com/helios
#   Target nested files with `...` syntax. e.g., "pulsestoreservice/..."
alias testcluster="BACKEND_TEST=singlestore.com/helios/graph/cluster_tests/s2monitoring GO_TEST_VERBOSE='-v -run TestEndToEnd' make backend-cluster-test"
alias testintegration="BACKEND_TEST=monitoringalerts make backend-integration-test"
alias testdb="make postgres-test-reset && BACKEND_TEST=data/pulsedata make backend-db-test"
alias testpulse="BACKEND_TEST=pulsestoreservice make backend-integration-test"

# Setup helios env to run notebooks locally
setup-notebooks() {
  set -e

  log() { echo "[$1] $2"; }

  log "info" "Starting notebook setup process..."

  log "info" "Running FISSION=1 make kube-init..."
  FISSION=1 make kube-init

  log "info" "Running make nova-setup-gateway..."
  make nova-setup-gateway

  log "info" "Enabling JupyterNotebooks and NotebookCodeService feature flags..."

  source helios/get_private_auth_header.sh
  auth_header_jwt=$(get_private_auth_header)

  org_id="d7d4c050-3ced-49e1-8cff-a7e8eb95e691"

  log "info" "Using organization ID: $org_id"

  log "info" "Enabling JupyterNotebooks feature flag..."
  gql "mutation { featureFlagEnable(organizationID: \"$org_id\", flag: JupyterNotebooks) }" || return 1

  log "info" "Enabling NotebookCodeService feature flag..."
  gql "mutation { featureFlagEnable(organizationID: \"$org_id\", flag: NotebookCodeService) }" || return 1

  log "info" "Running make frontend-notebooks-start..."
  make frontend-notebooks-start
}

# Prep projects for a diff
alias pbf="bf && make lint-fix && make lint && make test"
alias lint="hel && make cp-tsc && make cp-lint-fix"
alias pstudio="studio && cd frontend && npm run prettier && npm run lint && npm run tsc && npm run test"

# Other
alias bast="ssh bastion-1b"
alias p2="pyenv global 2.7.17"
alias p3="pyenv global 3.6.3"
alias ss="gnome-screenshot -a -f /tmp/ss.png && satty --filename /tmp/ss.png"

alias settoken_prd="singlestore-auth-helper --baseURL https://portal.singlestore.com/admin/admin-sso --env-name=TOKEN && export TOKEN"
alias e2e-email-off='hel && kcadm-login && kcadm update realms/memsql -s verifyEmail=false'

# pullai: Update heliosai, singlestore-ai and singlestore-nexus, unified-model-gateway repos
# Usage: pullai (pulls latest main for all AI repos)
unalias pullai 2>/dev/null # Remove old alias if it exists
function pullai {
  local orig_dir=$(pwd)
  local cyan='\033[1;36m'
  local green='\033[1;32m'
  local reset='\033[0m'

  echo -e "${cyan}==> Pulling heliosai...${reset}"
  cd ~/projects/heliosai/ && git checkout main && git pull &&

  echo -e "${cyan}==> Pulling singlestore-nexus...${reset}"
  cd ~/projects/singlestore-nexus/ && git checkout main && git pull &&

  echo -e "${cyan}==> Pulling singlestore-ai...${reset}"
  cd ~/projects/singlestore-ai/ && git checkout master && git pull &&

  echo -e "${cyan}==> Pulling unified-model-gateway...${reset}"
  cd ~/projects/unified-model-gateway/ && git checkout main && git pull &&

  echo -e "${cyan}==> Pulling helios...${reset}"
  cd ~/projects/helios/ && git checkout master && git pull

  cd "$orig_dir" # Always return, regardless of success/failure
  echo -e "${green}==> Done.${reset}"
}

function keepheaders() {
  keyword=$1  # Keyword to grep for

  # Read the complete input from stdin into the variable 'input'
  input=$(cat)

  # Extract the header (assuming it starts with NAME)
  header=$(echo "$input" | grep "^NAME")

  # Extract the lines containing the keyword
  lines=$(echo "$input" | grep "$keyword")

  # Print them together
  echo -e "$header\n$lines"
}

# Install memsql cluster-in-a-box
export SINGLESTORE_LICENSE=BGM5MjQwZGE3Nzg0MTRiMDk5NWNlNzAwOTQ4MTQwZWZjAAAAAAAAAAAAAAIAAAAAAAQwNgIZAJd6ds/wagCQvs1asVWyN40v0LVlYTs6CwIZAMff+F4bKAPsYRY8HW2h/6n5O6DjikyYAg==
export ROOT_PASSWORD="d"
alias ciab="docker rm -f singlestore-ciab || true && \
    docker run -i --init \
    --name singlestore-ciab \
    -e LICENSE_KEY=$SINGLESTORE_LICENSE \
    -e ROOT_PASSWORD=$ROOT_PASSWORD \
    -p 3306:3306 \
    singlestore/cluster-in-a-box && \
    docker start singlestore-ciab"

alias vpn-on="sudo tailscale up \
    --login-server https://headscale.internal.memcompute.com \
    --accept-routes \
    --operator=$USER"
alias vpn-off="tailscale down"
