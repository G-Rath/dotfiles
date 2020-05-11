findinhere() {
  grep -rn "$@"
}

export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

alias re-source='echo re-sourcing .profile... && source ~/.profile'

alias tf=terraform

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

# comm <(git branch -r --merged origin/master) <(git branch -r --merged origin/production) -12
# comm <(git branch -r --merged origin/master) <(git branch -r --merged origin/production) -12 | awk -F/ '/\/feature\/access/{print $2"/"$3}' | xargs -I % git push origin --delete %
