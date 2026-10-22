# dotfiles

Machine configuration for two Macs (macbook, mini) and a Windows gaming PC, managed with
[chezmoi](https://www.chezmoi.io). The repo is cloned to `~/repos/chezmoi` on every machine (set by
`sourceDir` in `home/.chezmoi.toml.tmpl`). Secrets are GPG-encrypted to the key on the YubiKey.

## Layout

    .chezmoiroot             one line, "home": chezmoi's source tree is ./home, so everything else at the
                             repo root (the files below) is not installed into the home directory
    setup.sh, setup.ps1      entry points; only setup.sh (and public.asc) are published at sheatsley.me
    autologin.ps1, nas.ps1, ohmgraphite-token.ps1
                             (Windows) enable automatic sign-in, save the NAS password, set the OhmGraphite
                             token; each reads a line of stdin
    brew-sync                adds the Homebrew packages installed on a Mac to .chezmoidata/packages.yaml (alias in .zshrc)
    MAINTENANCE.md           how to change things: which file to edit and which command to run
    .gitattributes           pins LF line endings (Git for Windows would otherwise convert to CRLF)
    home/                    everything chezmoi manages
      .chezmoi.toml.tmpl       template for the per-machine chezmoi config (written once by `chezmoi init`)
      .chezmoidata/            plain data (YAML) that templates read: packages.yaml (Homebrew), windows.yaml
                               (keyboard, theme, NAS, Quick access, repos, apps)
      .chezmoitemplates/       shared snippets other templates include (PowerShell and shell helpers)
      .chezmoiignore           per-OS list of things to skip (itself a template)
      .chezmoiscripts/darwin/  the macOS steps, one script per task of the old yadm bootstrap
      .chezmoiscripts/windows/ the Windows steps, one script per concern
      dot_*, private_dot_*     dotfiles: dot_ becomes ".", private_ makes the directory mode 0700
      dot_config/homebrew/Brewfile.tmpl   generates the Brewfile from .chezmoidata/packages.yaml
      dot_startup/             (Windows) files copied to ~/.startup; each gets a shortcut in shell:startup
                               (move-videos.ps1 moves recordings to the NAS)

## What happens on a new Mac

1. Plug in the YubiKey and press it (types `bash <(curl -L sheatsley.me/setup.sh)`).
2. `setup.sh` installs the command line tools and Homebrew, then chezmoi, gnupg, and pinentry-mac.
3. It downloads `sheatsley.me/public.asc`, imports it only if its fingerprint equals the one pinned in
   `setup.sh`, and trusts it (no YubiKey needed for this step).
4. It clones this repo to `~/repos/chezmoi` and refuses to continue unless `HEAD` is signed by that key.
5. `chezmoi init` asks "Which Mac is this" (macbook or mini) and writes the config. The gpg-agent config is
   applied first and the agent restarted, so the PIN prompt uses pinentry-mac.
6. `chezmoi apply` writes the dotfiles and decrypts the secrets, then runs, in order:

   | Script | What it does (old yadm bootstrap task) |
   |---|---|
   | `run_after_10-computer-name` | sets ComputerName, HostName, LocalHostName to the machine (`computer_name`) |
   | `run_after_20-brew-bundle` | `brew bundle install`, then `brew bundle cleanup --force`, from the generated Brewfile (`brew_packages`) |
   | `run_after_30-pip-packages` | `pip3 install --upgrade` from `~/.config/pip/packages` (`pip_packages`) |
   | `run_after_40-gpg-agent` | makes gpg-agent serve the YubiKey to ssh (`gpg_agent`) |
   | `run_after_50-repo-remote` | switches this repo's remote from https to ssh (`yadm_repo`) |
   | `run_after_60-git-repos` | clones/pulls the repos in `~/.config/git/repos` into `~/repos` (`git_repos`) |
   | `run_onchange_after_70-macos-defaults` | the `defaults write` commands (`macos_defaults`) |
   | `run_after_80-firewall` | turns on the application firewall (asks for sudo only if it is off) |

Not ported because chezmoi makes them unnecessary: `yadm alt` (replaced by the template and data files),
`git-crypt unlock` (replaced by chezmoi's gpg encryption), the public-key task (done by `setup.sh`).

Re-run any time: every step probes first, so finished steps are skipped and failed ones are retried.

## What happens on a Windows reformat

1. `winget install Git.Git`
2. Open Git Bash as administrator and press the YubiKey.
3. `setup.sh` asks for the computer name (first run only) and, for each that is not set up yet, your Windows
   password (automatic sign-in), the NAS password, and the OhmGraphite token (all hidden). It downloads
   `sheatsley.me/public.asc`, imports it only if its fingerprint equals the one pinned in `setup.sh`, clones the
   repo, and refuses to go on unless `HEAD` is signed by that key (all with the gpg bundled with Git for
   Windows). Then it runs the clone's `setup.ps1` in PowerShell, piping the secrets in.
4. `setup.ps1` installs chezmoi and Gpg4win, trusts your key (from the YubiKey) in Gpg4win's keyring, checks
   the signature again, runs `chezmoi init` and `chezmoi apply`, then runs `autologin.ps1`, `nas.ps1`, and
   `ohmgraphite-token.ps1`.
5. Reboot if a step says "Reboot required", and open the NAS from Explorer (it appears as a network location).

`chezmoi apply` runs these scripts, in order (`chezmoi apply` alone stops at the first failure; use `--keep-going`):

| Script | What it does |
|---|---|
| `05-execution-policy` | lets PowerShell run local scripts (sets the current user to RemoteSigned if nothing sets a policy) |
| `10-network-private` | sets connected networks to Private |
| `20-keyboard`, `21-dark-mode`, `22-explorer` | keyboard repeat, dark theme, show hidden files and extensions |
| `23-desktop` | solid black background, hides the built-in desktop icons |
| `25-quick-access` | pins Recycle Bin, Desktop, Documents, Downloads, Videos, in that order |
| `26-timezone` | turns on "Set time zone automatically" (and the location access it needs) |
| `27-mouse` | turns off "Enhance pointer precision" (mouse acceleration) |
| `30-wake-on-lan` | wake-on-LAN (warns and skips when there is no physical Ethernet adapter) |
| `40-computer-name` | sets the computer name |
| `50-startup-shortcuts` | a shortcut in `shell:startup` for each script in `~/.startup` |
| `55-nas-location` | adds `\\unas\media` to Explorer as a network location (a shortcut, not a drive letter) |
| `60-apps` | winget installs from `apps` in `windows.yaml`; prints URLs for `manual_apps` |
| `61-ohmgraphite` | downloads OhmGraphite to `C:\Apps\OhmGraphite` |
| `62-ohmgraphite-service` | writes its config from the template, installs the service, starts it once the token is set |
| `65-repos` | clones/pulls the public repos in `windows.yaml` (e.g. `games`) into `~/repos` |
| `70-taskbar` | pins the taskbar apps in order (a layout file plus the Start layout policy; applies at the next sign-in) |
| `71-taskbar-options` | taskbar buttons: combine when full, hide search, Task View, and Widgets (removed with its package; applies at the next sign-in) |
| `72-onedrive` | disables OneDrive by policy, uninstalls it, and removes its sign-in entry and Explorer folder |
| `75-fancontrol` | copies `~/.config/fancontrol/userConfig.json` into FanControl when the repo's copy changes |
| `80-system-restore` | turns on System Restore, caps its space, and creates a restore point every day (a scheduled task) |
| `90-desktop-clean` | deletes everything on your Desktop and the Public Desktop, on every apply |

### Automatic sign-in, the NAS password, and the OhmGraphite token

None of these secrets is stored in the repo. `autologin.ps1` hands the Windows password to Sysinternals
Autologon, which keeps it as an LSA secret. `ohmgraphite-token.ps1` sets the InfluxDB token as a machine-wide
environment variable that OhmGraphite's config refers to. `nas.ps1` saves the NAS password in Windows Credential Manager
(for the user and host under `nas` in `windows.yaml`); Windows then uses it for `\\unas\media`, which
`55-nas-location` adds to Explorer as a network location and `move-videos.ps1` writes to. Both are one-time settings, so
once they exist the scripts exit without asking. Ways to supply the passwords:

- Interactively (the default): `setup.sh` prompts for each one that is missing, hidden. An empty answer skips it.
- Unattended: pipe all three in, the Windows password on the first line, the NAS password on the second, and the
  token on the third (an empty line skips one), and set `COMPUTER_NAME` too on a first run, since there is no terminal to ask:

        printf '%s\n%s\n%s\n' "$WINPW" "$NASPW" "$TOKEN" | COMPUTER_NAME=CX4200A bash <(curl -L sheatsley.me/setup.sh)

- On their own, from an elevated PowerShell window (prompts without echo), for example after changing a password:

        $env:DOTFILES_FORCE_AUTOLOGON = '1'; & ~\repos\chezmoi\autologin.ps1
        $env:DOTFILES_FORCE_NAS = '1'; & ~\repos\chezmoi\nas.ps1
        $env:DOTFILES_FORCE_INFLUX = '1'; & ~\repos\chezmoi\ohmgraphite-token.ps1

## Environment variables

| Variable | Effect |
|---|---|
| `MACHINE` | (macOS) skip the "Which Mac is this" question: `macbook` or `mini` |
| `COMPUTER_NAME` | (Windows) set the computer name without prompting (also renames on a re-run) |
| `DOTFILES_SKIP_SYNC=1` | use the local repo as it is, without cloning or pulling |
| `DOTFILES_SKIP_VERIFY=1` | do not require a signed `HEAD` (for testing with unsigned commits) |
| `DOTFILES_NO_YUBIKEY=1` | (macOS) testing without the YubiKey (a VM): skips the encrypted files and the steps that need the card |
| `DOTFILES_FORCE_AUTOLOGON=1` | (Windows) redo automatic sign-in even if it is already enabled (asks for the password again) |
| `DOTFILES_FORCE_NAS=1` | (Windows) replace the saved NAS password |
| `DOTFILES_FORCE_INFLUX=1` | (Windows) replace the OhmGraphite token |
| `NAS_HOST` | (Windows) NAS whose saved password `setup.sh` looks for (default `unas`; keep equal to `nas.host`) |
| `OHM_TOKEN_VAR` | (Windows) variable holding the OhmGraphite token (default `OHMGRAPHITE_INFLUX_TOKEN`; keep equal to `ohmgraphite.token_var`) |
| `KEY_URL` | testing: where `setup.sh` downloads the public key from (default `https://sheatsley.me/public.asc`); it must match the pinned fingerprint |
| `GITEA_HOST` | (macOS) host for `gitea:` entries in the repos list (default `gitea.lan`) |

## Secrets

Two files are stored encrypted (`encrypted_*` in the source state): `~/.config/git/repos` and
`~/.ssh/known_hosts`. The ssh public key `~/.ssh/1A2405C9E6BFBE34.pub` is stored as a plain file, since it is
public. chezmoi decrypts them on every `apply`, so
expect the YubiKey to ask for its PIN (and a touch, depending on how the key is set up). Add or update one with

    chezmoi add --encrypt ~/.config/git/repos

The Windows and NAS passwords and the OhmGraphite token are deliberately not stored in the repo; see "Automatic sign-in, the NAS password, and the OhmGraphite token" above.

## Migrating a Mac from yadm (one time)

Do this on a Mac that currently runs yadm, with the YubiKey inserted and the repo unlocked (so the secret
files are readable in your home directory).

    brew install chezmoi
    git clone https://github.com/sheatsley/dotfiles.git ~/repos/chezmoi && cd ~/repos/chezmoi

1. Replace the old layout with this one. Unpack the zip somewhere, then:

        git rm -r -q .config .git-crypt .gnupg .ssh .gitattributes .gitconfig .zshrc
        cp -R /path/to/unpacked/dotfiles-chezmoi/. .

2. Remove the dotfiles repo itself from the repos list if it is there (this repo lives in `~/repos/chezmoi`,
   so a `github:sheatsley/dotfiles` line would clone a second copy to `~/repos/dotfiles`):

        $EDITOR ~/.config/git/repos

3. Create the chezmoi config (it is what turns on gpg encryption), then store the two secrets, encrypted, and the
   public key, plain, from the live files:

        chezmoi -S ~/repos/chezmoi init
        chezmoi add --encrypt ~/.config/git/repos ~/.ssh/known_hosts
        chezmoi add ~/.ssh/1A2405C9E6BFBE34.pub

4. Remove what yadm generated, so chezmoi can write its own versions:

        rm -f ~/.config/homebrew/Brewfile ~/.config/homebrew/Brewfile\#\#hostname.* ~/.config/macos/defaults \
              ~/.config/macos/.defaults_applied ~/.gitattributes
        rm -rf ~/.git-crypt

5. Preview, then commit (signed) and push:

        chezmoi diff
        git add -A && git commit -S -m "Migrate from yadm to chezmoi" && git push

6. Publish the new `setup.sh` at `sheatsley.me/setup.sh` (and your public key at `sheatsley.me/public.asc`). The old `setup.sh` clones this repo with yadm
   and would no longer find a bootstrap.
7. Run `bash ~/repos/chezmoi/setup.sh` on this Mac. Once it succeeds, remove yadm's leftovers:

        rm -rf ~/.local/share/yadm ~/.config/yadm

   (`brew bundle cleanup` has already uninstalled yadm and git-crypt.)
8. On the other Mac, run the YubiKey command from `sheatsley.me` after step 6, then the same cleanup.

## Useful chezmoi commands

    chezmoi diff                         # what would change (decrypts secrets, so it uses the YubiKey)
    chezmoi apply --dry-run --verbose    # preview file changes (scripts are not run in a dry run)
    chezmoi managed                      # files chezmoi owns
    chezmoi execute-template < f.tmpl    # render a template to see the result
    chezmoi cd                           # open a shell in the source directory
