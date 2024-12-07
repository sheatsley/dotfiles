export DOCKER_HOST="ssh://fenestras"                         # set docker host
export GPG_TTY="$(tty)"                                      # set tty device for current shell
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket) # set ssh agent socket
export ZSH_CUSTOM=$HOME"/.ohmyzsh/"                          # set custom plugin folder
export ZSH=$HOME"/.ohmyzsh/ohmyzsh"                          # set oh-my-zsh-installation
ENABLE_CORRECTION="true"                                     # enable command auto-correction
plugins=(copyfile zsh-autosuggestions)                       # load files into clipboard & provide fish-like autosuggestions
ZSH_THEME="agnoster"                                         # load agnoster theme
source $ZSH/oh-my-zsh.sh                                     # enable above settings
gpgconf --launch gpg-agent                                   # enable yubikey for ssh
function zwidget::clear                                      # clear terminal by scrolling (populates scrollback buffer)
{
  echo -ne "\033[6n" > /dev/tty
  read -t 1 -s -d 'R' row < /dev/tty
  row=${row##*\[}
  row=$((${row%;*} - 1))
  if [ $row -gt 0 ]; then
    tput indn $row && clear && zle redisplay
  fi
}
zle -N zwidget::clear
bindkey '^l' zwidget::clear
