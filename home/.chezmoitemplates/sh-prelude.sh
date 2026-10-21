# This file defines the helpers shared by the macOS scripts in
# .chezmoiscripts/darwin. chezmoi pastes it below the shebang line of each of
# those scripts (through the template directive on their second line), so every
# script is self-contained when it runs. Do not put template braces in this
# file, since it would then include itself.
set -euo pipefail

log() {
  # This function prints a timestamped progress line so that the output of a
  # long apply is easy to follow (and audit afterwards).
  #
  # :param $*: the text to print
  # :return: None
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

die() {
  # This function prints an error message to stderr and exits, which marks the
  # calling script as failed so that chezmoi reports it (and retries it on the
  # next apply).
  #
  # :param $*: the message to print
  # :return: does not return (exits with status 1)
  printf '[%s] ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2
  exit 1
}

load_brew() {
  # This function puts Homebrew on PATH for the calling script, so that brew
  # and the tools it installed (python, gpg, mas) can be used even when chezmoi
  # was started from a shell that has not read ~/.zprofile.
  #
  # :return: None (exits if Homebrew is not installed; run setup.sh first)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    die "Homebrew is not installed (run setup.sh)"
  fi
}
