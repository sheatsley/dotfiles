#!/usr/bin/env bash
#
# This script is the entry point for initializing a machine from
# https://github.com/sheatsley/dotfiles. It is meant to be typed by the YubiKey:
#
#     bash <(curl -L sheatsley.me/setup.sh)
#
# On macOS, the following tasks are performed (if necessary):
#
#     1. Install the Xcode command line tools (git)
#     2. Install Homebrew, then chezmoi, gnupg, and pinentry-mac
#     3. Download the public key (sheatsley.me/public.asc), check it against the
#        fingerprint pinned in this script, and add it to the gpg keyring with
#        ultimate trust
#     4. Clone/pull the dotfiles repo to ~/repos/chezmoi
#     5. Verify that HEAD is signed by that key
#     6. Generate the chezmoi config, start gpg-agent with the managed
#        gpg-agent.conf, and apply the repo
#
# On Windows, run it from an elevated Git Bash (right-click, "Run as
# administrator"). Git Bash is only a launcher there: this script asks for the
# computer name, downloads the public key from sheatsley.me/public.asc and checks
# it against the fingerprint pinned below, clones the repo and verifies the
# signature on HEAD (with the gpg that ships with Git for Windows), and hands off
# to the repo's own setup.ps1 in Windows PowerShell, which does the real work.
# This file is therefore the only thing published at sheatsley.me besides the
# public key. If automatic sign-in is not enabled yet, it also asks for
# your Windows password, and if the NAS password or the OhmGraphite token is not
# saved yet, for those too (all hidden), and pipes them to setup.ps1 in that order,
# one per line; none is written anywhere but its own store. To run unattended,
# pipe all three in instead (an empty line skips one), which skips the prompts
# (set COMPUTER_NAME as well on a first run, since there is no terminal to ask):
#
#     printf '%s\n%s\n%s\n' "$WINPW" "$NASPW" "$TOKEN" | COMPUTER_NAME=CX4200A bash <(curl -L sheatsley.me/setup.sh)
#
# Every task probes the system before changing it, so re-running this script
# after an error (e.g., a network failure) is safe. The following environment
# variables are optional: MACHINE (macOS) and COMPUTER_NAME (Windows) skip the
# question chezmoi would ask, DOTFILES_SKIP_SYNC=1 uses the local repo as-is
# without fetching (for testing before pushing), DOTFILES_SKIP_VERIFY=1 skips
# the signature check (for testing with unsigned commits),
# DOTFILES_FORCE_AUTOLOGON=1 redoes automatic sign-in even if it is already
# enabled, DOTFILES_NO_YUBIKEY=1 (macOS) skips everything that needs the YubiKey
# (for a test VM), DOTFILES_FORCE_NAS=1 and DOTFILES_FORCE_INFLUX=1 do the same for the
# NAS password and the OhmGraphite token, NAS_HOST names the NAS whose saved
# password is looked for and OHM_TOKEN_VAR names the variable that holds the token
# (keep them equal to nas.host and ohmgraphite.token_var in
# home/.chezmoidata/windows.yaml), and KEY_URL overrides where the public key is
# downloaded from on Windows (the pinned fingerprint still has to match).
set -euo pipefail

REPO="sheatsley/dotfiles"
FINGERPRINT="D4FA4A5C5DA6CCB90433D9921A2405C9E6BFBE34"
KEY_ID="${FINGERPRINT: -16}"
KEY_URL="${KEY_URL:-https://sheatsley.me/public.asc}"
SRC="$HOME/repos/chezmoi"
NAS_HOST="${NAS_HOST:-unas}"
OHM_TOKEN_VAR="${OHM_TOKEN_VAR:-OHMGRAPHITE_INFLUX_TOKEN}"

log() {
  # This function prints a highlighted heading for the task that is starting.
  #
  # :param $*: the text to print
  # :return: None
  printf '==> %s\n' "$*"
}

die() {
  # This function prints an error message to stderr and exits.
  #
  # :param $*: the message to print
  # :return: does not return (exits with status 1)
  echo "setup: $*" >&2
  exit 1
}

valid_name() {
  # This function checks that a string is a legal Windows computer name: 1 to
  # 15 letters, digits, or hyphens, not starting or ending with a hyphen, and
  # not all digits.
  #
  # :param $1: the candidate name
  # :return: 0 if the name is valid, otherwise 1
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,13}[A-Za-z0-9])?$ && ! "$1" =~ ^[0-9]+$ ]]
}

ensure_clt() {
  # This function installs the Xcode command line tools (which provide git) and
  # waits for the installer to finish, as the yadm version of this script did.
  # Nothing happens if they are already installed.
  #
  # :return: None
  if xcode-select --print-path &>/dev/null; then
    log "Command line tools already installed"
    return 0
  fi
  log "Installing the command line tools (accept the dialog that appears)"
  xcode-select --install &>/dev/null || true
  until xcode-select --print-path &>/dev/null; do
    sleep 5
  done
}

ensure_homebrew() {
  # This function installs Homebrew if it is missing (it asks for your password
  # through sudo) and puts it on PATH for the rest of this script. Only Apple
  # silicon is supported (/opt/homebrew), as in the yadm bootstrap.
  #
  # :return: None
  local installer
  if [[ ! -x /opt/homebrew/bin/brew ]]; then
    log "Installing Homebrew"
    installer="$(mktemp)"
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
    /bin/bash "$installer"
    rm -f "$installer"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
}

ensure_tools() {
  # This function installs the tools needed before chezmoi can run: chezmoi
  # itself, gnupg (to trust the key, verify the signature, and decrypt), and
  # pinentry-mac (the PIN prompt that gpg-agent.conf points at). The Brewfile
  # lists them too, so the cleanup step keeps them.
  #
  # :return: None
  local formula
  for formula in chezmoi gnupg pinentry-mac; do
    if brew list --formula "$formula" &>/dev/null; then
      log "$formula already installed"
    else
      log "Installing $formula"
      brew install "$formula"
    fi
  done
}

key_trusted() {
  # This function checks whether the public key is in the keyring with ultimate
  # trust. It reads $KEY_ID from the script scope.
  #
  # :return: 0 if the key is present and ultimately trusted, otherwise 1
  local trust
  trust="$(gpg --with-colons --list-keys "$KEY_ID" 2>/dev/null | awk -F: '$1 == "pub" { print $9; exit }' || true)"
  [[ "$trust" == "u" ]]
}

trust_key_from_url() {
  # This function adds the public key to the keyring from $KEY_URL and trusts
  # it (no YubiKey is needed, because the trust comes from the fingerprint pinned
  # in this script). The
  # download is inspected before it is imported: if its primary-key fingerprint
  # is not $FINGERPRINT, nothing is imported. Nothing happens if the key is
  # already trusted.
  #
  # :return: None
  local tmp fpr
  if key_trusted; then
    log "Key $KEY_ID already trusted"
    return 0
  fi

  # download the key and compare its fingerprint with the pinned one
  log "Importing $KEY_ID from $KEY_URL"
  tmp="$(mktemp -d)"
  curl -fsSL "$KEY_URL" -o "$tmp/key.asc" || { rm -rf "$tmp"; die "could not download $KEY_URL"; }
  fpr="$(gpg --with-colons --import-options show-only --import "$tmp/key.asc" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }' || true)"
  if [[ "$fpr" != "$FINGERPRINT" ]]; then
    rm -rf "$tmp"
    die "the downloaded key has fingerprint '${fpr:-none}', not the pinned $FINGERPRINT; refusing to import it"
  fi
  gpg --import "$tmp/key.asc" 2>/dev/null

  # set ultimate trust (6) from a file, since piping to gpg is unreliable here
  printf '%s:6:\n' "$FINGERPRINT" >"$tmp/trust.txt"
  gpg --import-ownertrust "$tmp/trust.txt" 2>/dev/null
  rm -rf "$tmp"
  key_trusted || die "could not set ultimate trust on $KEY_ID"
}

sync_repo() {
  # This function clones the dotfiles repo to ~/repos/chezmoi over https (ssh is
  # not set up yet on a new machine; the apply switches the remote to ssh), or
  # fast-forwards an existing clone.
  #
  # :return: None
  if [[ "${DOTFILES_SKIP_SYNC:-}" == "1" ]]; then
    log "Skipping sync (DOTFILES_SKIP_SYNC=1); using the repo as it is"
    return 0
  fi
  log "Syncing dotfiles ($REPO)"
  if [[ ! -d "$SRC/.git" ]]; then
    mkdir -p "$(dirname "$SRC")"
    git clone "https://github.com/$REPO.git" "$SRC"
  else
    git -C "$SRC" pull --ff-only
  fi
}

verify_head() {
  # This function refuses to continue unless HEAD carries a good signature from
  # the trusted key, so that nothing in the repo runs unless you signed it.
  #
  # :return: None (exits if the signature is not good)
  local status
  if [[ "${DOTFILES_SKIP_VERIFY:-}" == "1" ]]; then
    echo "setup: skipping signature verification (DOTFILES_SKIP_VERIFY=1)" >&2
    return 0
  fi
  log "Verifying the signature on HEAD"
  status="$(git -c "gpg.program=$(command -v gpg)" -C "$SRC" log -1 --format=%G? HEAD)"
  [[ "$status" == "G" ]] || die "HEAD is not signed by a trusted key (git status '$status'); refusing to apply"
}

setup_macos() {
  # This function runs the macOS flow described at the top of this file.
  #
  # :return: None
  ensure_clt
  ensure_homebrew
  ensure_tools
  trust_key_from_url
  sync_repo
  verify_head

  # generate the chezmoi config (MACHINE, if set, is read by .chezmoi.toml.tmpl)
  log "Configuring chezmoi"
  chezmoi -S "$SRC" init

  # apply gpg-agent.conf first and restart the agent, so that it starts with
  # pinentry-mac before chezmoi needs the YubiKey to decrypt files
  GPG_TTY="$(tty || true)"
  export GPG_TTY
  chezmoi -S "$SRC" apply "$HOME/.gnupg/gpg-agent.conf"
  gpgconf --kill gpg-agent

  # without the YubiKey (a test VM), leave out the encrypted files, which cannot be decrypted
  local -a apply_args=(--keep-going)
  if [[ "${DOTFILES_NO_YUBIKEY:-}" == "1" ]]; then
    log "DOTFILES_NO_YUBIKEY=1: skipping the encrypted files and the steps that need the YubiKey"
    apply_args+=(--exclude=encrypted)
  fi

  # apply the repo; a failing script does not stop the others
  log "Applying (a failing script does not stop the others)"
  if ! chezmoi -S "$SRC" apply "${apply_args[@]}"; then
    die "chezmoi apply finished with errors; fix the cause and re-run (finished steps are skipped)"
  fi
  log "Done"
}

autologin_enabled() {
  # This function checks whether automatic sign-in is already enabled for the
  # current user, by asking PowerShell to read the Winlogon registry key (done
  # there rather than with reg.exe, whose /v switch Git Bash would rewrite as a
  # path).
  #
  # :return: 0 if automatic sign-in is enabled for this user, otherwise 1
  powershell.exe -NoLogo -NoProfile -Command \
    '$w = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"; if ($w.AutoAdminLogon -eq "1" -and $w.DefaultUserName -eq $env:USERNAME) { exit 0 } else { exit 1 }' \
    >/dev/null 2>&1
}

nas_credential_present() {
  # This function checks whether Windows Credential Manager already holds a
  # saved credential for the NAS (done in PowerShell, like autologin_enabled).
  #
  # :return: 0 if a credential for $NAS_HOST is saved, otherwise 1
  powershell.exe -NoLogo -NoProfile -Command \
    "if ((cmdkey /list:${NAS_HOST} | Out-String) -match 'Target:') { exit 0 } else { exit 1 }" \
    >/dev/null 2>&1
}

ohm_token_present() {
  # This function checks whether the machine-wide variable that holds the
  # OhmGraphite token is already set.
  #
  # :return: 0 if $OHM_TOKEN_VAR is set, otherwise 1
  powershell.exe -NoLogo -NoProfile -Command \
    "if ([Environment]::GetEnvironmentVariable('${OHM_TOKEN_VAR}', 'Machine')) { exit 0 } else { exit 1 }" \
    >/dev/null 2>&1
}

run_setup_ps1() {
  # This function runs setup.ps1 in Windows PowerShell, sharing this script's
  # stdin (so a piped password reaches it).
  #
  # :param $1: the Windows path of setup.ps1
  # :return: the exit status of setup.ps1
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$1"
}

setup_windows() {
  # This function runs the Windows flow: it asks for the computer name here,
  # since prompts are unreliable when powershell.exe runs under Git Bash
  # (skipped if chezmoi is already configured), trusts the pinned key, clones the
  # repo and verifies HEAD, and runs the repo's setup.ps1 in Windows PowerShell.
  # If automatic sign-in or the NAS password still has to
  # be configured and this script is attached to a terminal, it asks for the
  # secrets (hidden) and pipes them to setup.ps1; if stdin is a pipe, it is
  # passed through untouched.
  #
  # :return: None
  local win_ps1
  command -v powershell.exe >/dev/null || die "powershell.exe not found"
  command -v git >/dev/null || die "git not found (run: winget install Git.Git)"
  command -v gpg >/dev/null || die "gpg not found (it ships with Git for Windows)"

  # ask for the computer name
  if [[ -z "${COMPUTER_NAME:-}" && ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]]; then
    [[ -t 0 ]] || die "set COMPUTER_NAME when stdin is not a terminal (a piped password would be read as the name)"
    until valid_name "${COMPUTER_NAME:-}"; do
      read -r -p "Computer name for this PC (max 15 chars, letters/digits/hyphen): " COMPUTER_NAME
    done
  fi
  export COMPUTER_NAME="${COMPUTER_NAME:-}"

  # trust the pinned key, then clone the repo and refuse to continue unless HEAD
  # is signed by it; only then is anything from the repo run
  trust_key_from_url
  sync_repo
  verify_head
  win_ps1="$(cygpath -w "$SRC/setup.ps1")"

  # ask for the passwords that are still needed here, hidden, and pipe them to
  # setup.ps1 (Windows password, NAS password, OhmGraphite token, in that order; a
  # blank line stands in for one that is not needed, since each script uses up
  # its line)
  local login_pw="" nas_pw="" ohm_token="" prompted=0
  if [[ -t 0 ]]; then
    if [[ "${DOTFILES_FORCE_AUTOLOGON:-}" == "1" ]] || ! autologin_enabled; then
      read -r -s -p "Windows password for automatic sign-in as ${USERNAME:-this user} (empty to skip): " login_pw
      echo
      prompted=1
    fi
    if [[ "${DOTFILES_FORCE_NAS:-}" == "1" ]] || ! nas_credential_present; then
      read -r -s -p "Password for your NAS account on ${NAS_HOST} (empty to skip): " nas_pw
      echo
      prompted=1
    fi
    if [[ "${DOTFILES_FORCE_INFLUX:-}" == "1" ]] || ! ohm_token_present; then
      read -r -s -p "InfluxDB token for OhmGraphite (empty to skip): " ohm_token
      echo
      prompted=1
    fi
  fi
  if (( prompted )); then
    printf '%s\n%s\n%s\n' "$login_pw" "$nas_pw" "$ohm_token" | run_setup_ps1 "$win_ps1"
    login_pw="" nas_pw="" ohm_token=""
  else
    run_setup_ps1 "$win_ps1"
  fi
}

main() {
  # This function picks the flow for the current OS.
  #
  # :return: None
  case "$(uname -s)" in
    Darwin) setup_macos ;;
    MINGW*|MSYS*|CYGWIN*) setup_windows ;;
    *) die "unsupported OS: $(uname -s)" ;;
  esac
}

# run main when executed (as bash <(curl ...) or curl | bash), but not when sourced for testing
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
