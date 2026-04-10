export GPG_TTY="$(tty)"                                      # set tty device for current shell
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket) # set ssh agent socket
ENABLE_CORRECTION="true"                                     # enable command auto-correction