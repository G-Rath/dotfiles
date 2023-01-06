findinhere() {
  grep -rn "$@"
}

#alias docker-compose="docker compose"
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

alias re-source='echo re-sourcing .profile... && source ~/.profile'

alias tf=terraform
alias tfi="terraform init"
alias tfp="terraform plan"
alias tfa="terraform apply"
alias tfs="terraform state"

complete -C terraform tf

# output just the headers of a request
alias curl-headers-only='curl -sSL -D - -o /dev/null'
alias curlho=curl-headers-only

# rm safety
alias rm='rm -I --preserve-root'

## a quick way to get out of current directory ##
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../'
alias cd.4='cd ../../../../'
alias cd.5='cd ../../../../..'

alias verdaccio='verdaccio -c $VERDACCIO_CONFIG_FILE'
alias npm_launch_package_repo='verdaccio'

alias find_not_world_writable='find -perm "0777"'
alias make_not_world_writable='find -perm 0777 $1'
#find -perm 0777 -exec chmod go-w {} +

alias tssh="ssh -T git@github.com"

# updates PS1 to be very short - useful when in deep directories, and using lots of tmux panels
alias shorten_prompt="PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\u\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$ '"

alias date_filename_stamp="date +'%FT%H-%M-%S%z'"

c2p() {
  results="$(cd_to_project $1)"

  if [ "$2" != "-s" ]; then
    echo "$results"
  fi

  cd $(echo "$results" | head -n1)
}

alias cursor_show="node -e \"process.stdout.write('\x1b[?25h');\""
alias cursor_hide="node -e \"process.stdout.write('\x1b[?25l');\""

alias ij='idea64.exe "$(wslpath -w $PWD)"'

# comm <(git branch -r --merged origin/master) <(git branch -r --merged origin/production) -12
# comm <(git branch -r --merged origin/master) <(git branch -r --merged origin/production) -12 | awk -F/ '/\/feature\/access/{print $2"/"$3}' | xargs -I % git push origin --delete %
alias git_update_main='git checkout master && git fetch --all --prune && git pull'

alias gfetch="git fetch --prune"
alias gfetcha="git fetch --prune --all"
alias gfa="git fetch --prune --all"

alias shfmt="docker run --rm -v $PWD:/work tmknom/shfmt -i 2 -ci"
alias pantheon=terminus
alias rsync="rsync -P"
alias count_folders_in_node_modules='find . -type d -name "node_modules" -exec find {} -mindepth 1 -maxdepth 1 -type d \; | wc -l'
alias count_fds="lsof | wc -l"
alias node-with-await="node --experimental-repl-await"
alias enable_globstar="shopt -s globstar"
alias audit_app_paths="npx audit-app --output paths | jq -nR '[inputs]'"
alias audit_app_paths_sorted="npx audit-app --output paths | sort --numeric-sort | jq -nR '[inputs]'"
alias ssm2ec2="node /c/Users/G-Rath/workspace/projects-ackama/aws-helpers/lib/bin/ssm2ec2.js"
alias tfpl="terraform providers lock \
  -platform=linux_arm64 \
  -platform=linux_amd64 \
  -platform=darwin_amd64 \
  -platform=windows_amd64"
alias tfpl2="terraform providers lock -platform=linux_amd64 -platform=darwin_amd64 -platform=windows_amd64"
alias browse_coverage='browse "$(wslpath -w coverage/lcov-report/index.html)"'

pnano() {
  file=${1?'must be provided'}
  nano "$file"
  prettier --write "$file"
}
alias go_test_with_coverage="go test ./... -coverprofile coverage/c.out; go tool cover -html=coverage/c.out -o coverage/coverage.html"

aws_list_ec2_instances() {
  aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[] | [][Tags[?Key==`Name`]|[0].Value, InstanceId] | sort_by(@, &[0])' \
    --output table
}

push_my_ssh_key_to_ec2_instance() {
  instance_id=${1:?'first arg must be instance id'}
  os_user=${2:-$DF_AWS_DEFAULT_EC2_USER}
  public_key_path=${3:-'~/.ssh/id_ed25519.pub'}

  aws ec2-instance-connect send-ssh-public-key \
    --instance-id "$instance_id" \
    --instance-os-user "$os_user" \
    --ssh-public-key "file://$public_key_path"
}
