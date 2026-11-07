#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

#
# Environment variables
#

export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket

# Disables client side decorations
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GTK_CSD=0

#
# Bash prompt customization
#

#CYAN="\033[038;5;51m"
#GREEN="\033[038;5;40m"
#RESET="\033[0m"

# only this works in Arch
#CYAN="\[$(tput setaf 51)\]"
#GREEN="\[$(tput setaf 40)\]"
CYAN="\[$(tput setaf 6)\]"
GREEN="\[$(tput setaf 2)\]"
RESET="\[$(tput sgr0)\]"


# checks whether the current dir is a part of a git repo
# if yes, returns the current active branch
getGitBranch() {
  local branch=$(git branch 2> /dev/null | sed -n '/^[^*]/d;s/*\s*\(.*\)/\1/p')

  if [[ -n "$branch" ]]; then
    if [[ -n "$(git status --porcelain)" ]]; then
      echo "⦓  $branch* ⦔"
    else
      echo "⦓  $branch  ⦔"
    fi
  fi
}

PS0=''
PS1="${CYAN}\n\w${GREEN} \$(getGitBranch)\n${CYAN}⦔ ${RESET}"
PS2='... '

