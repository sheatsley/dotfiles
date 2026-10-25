# Maintenance guide

How to change things in this repo: for each change, the file to edit and the command to run. Paths starting with
`home/` are in the repo (`~/repos/chezmoi`); everything under `home/` is what chezmoi manages. The repo is cloned
to `~/repos/chezmoi` on every machine, so edit there, then apply and publish as described under "Every change".

## Every change

The chezmoi commands below need no `-S`: `chezmoi init` writes `sourceDir = ~/repos/chezmoi` into
`~/.config/chezmoi/chezmoi.toml`. (`chezmoi source-path` shows where chezmoi is looking.)

1. Edit the file (or add it with `chezmoi add`, below).
2. Preview, then apply (Windows needs an elevated PowerShell; a plain `chezmoi apply` stops at the first failing
   script, so use `--keep-going`):

        chezmoi diff
        chezmoi apply --keep-going

3. Commit with a signature and push. `setup.sh` refuses to apply a repo whose `HEAD` is not signed by your key, so
   an unsigned commit on `main` breaks the next reformat:

        cd ~/repos/chezmoi
        git add -A && git commit -S -m "what changed" && git push

4. If you changed `setup.sh`, publish the new copy at `sheatsley.me/setup.sh`. That is the only file the
   YubiKey command downloads; `setup.ps1` comes from the signed clone, so changes to it need no publishing.

## Adding or changing a config file

The yadm habit works here: put the file where it lives on the machine, then tell chezmoi about it.

| What | Command |
|---|---|
| A new dotfile (e.g. `~/.config/app/config`) | `chezmoi add ~/.config/app/config` |
| You edited a managed file in place and want the repo to have it | `chezmoi re-add ~/.config/app/config` |
| A file with a secret in it (Mac only) | `chezmoi add --encrypt ~/.ssh/some_file` |
| You edited the copy in the repo and want it on this machine | `chezmoi apply` |

`add` puts the file under `home/` with chezmoi's names (`dot_` for a leading `.`, `private_` for mode 0700,
`encrypted_` for secrets). A file added on one OS is not installed on the other if `home/.chezmoiignore` lists it.
The Mac keeps app configs in `~/.config/<app>/`, and Windows follows the same convention (the FanControl config is
`~/.config/fancontrol/`). `home/.chezmoiignore` decides which OS gets which folder: the Mac folders are listed
there to keep them off Windows, and `.config/fancontrol` is listed to keep it off the Mac. When you add a new app
folder under `.config`, add it to that file for the OS that should not get it, or it is installed on both.
Windows can only have files under the home folder this way; anything that must go elsewhere (like `C:\Apps`) needs
a script, as OhmGraphite and FanControl have.

## macOS

| Change | Where | Then |
|---|---|---|
| Change the Dock apps | `home/.chezmoidata/macos.yaml` (`dock_apps`, in order; `path` is the `.app` bundle) | apply (the defaults script reruns when the list changes) |
| Record Homebrew packages you installed by hand | `brew-sync` (run it from anywhere on a Mac) | adds every installed formula, cask, tap, and Mac App Store app that `packages.yaml` does not list to the end of `common`, with its description; `brew-sync --dry-run` shows the additions first. Move a line to `macbook` or `mini` to make it specific to one Mac, then apply |
| Add a Homebrew formula, cask, tap, or Mac App Store app | `home/.chezmoidata/packages.yaml` (`common` for both Macs, `macbook` or `mini` for one) | apply (`brew bundle cleanup` also removes what you delete from the list) |
| Add a pip package | `~/.config/pip/packages` (managed file) | `re-add`, apply |
| Add a repo to clone into `~/repos` | `~/.config/git/repos` (encrypted) | `re-add` it (the YubiKey decrypts it), apply |
| A `defaults write` setting | `home/.chezmoiscripts/darwin/run_onchange_after_70-macos-defaults.sh.tmpl` | apply (it reruns when the file changes) |
| A new setup step | a new `run_after_NN-name.sh.tmpl` in `home/.chezmoiscripts/darwin/`, using `sh-prelude.sh` like the others | apply |

## Windows

All the values are in `home/.chezmoidata/windows.yaml`; edit one and apply.

| Change | Key in `windows.yaml` | Notes |
|---|---|---|
| Keyboard repeat, theme, hidden files and extensions | `keyboard`, `theme`, `explorer` | applied now; some need a sign-out |
| Install a program with winget | `apps` (`id`, `source` winget or msstore, optional `location`) | find the id with `winget search name`; a program that asks for an install root needs `location` |
| A program winget cannot install | `manual_apps` (`url`, `detect`, optional `path`) | the URL is printed at each apply until a program matching `detect` (an installed-programs or Start menu name) is installed, or the file at `path` exists |
| Taskbar order | `taskbar` | an id (fixed Windows app) or a `match` on the Start menu name; applies at the next sign-in. If an app shows a second icon when it runs, run `diagnose-taskbar.ps1` with the app open and add `rebuild: true` (plus `aumid` or `target`) to its entry |
| Taskbar buttons (combining, search box, Task View, Widgets) | `taskbar_options` | `combine` is always, when_full, or never; `search` is hidden, icon, or box; `task_view` and `widgets` are true or false (`widgets: false` removes the Widgets package, which Windows blocks any other way); applies at the next sign-in |
| Sunshine's certificate (name, CA, root fingerprint, lifetime) | `sunshine_cert` | see "Sunshine's certificate"; an empty `root_fingerprint` turns it off |
| SSH access to the Windows PC (keys, passwords, shell) | `ssh_server` | `authorized_keys` takes public keys, one per entry (get yours from `ssh-add -L`); `password_login` is false for keys only; `shell` is powershell or cmd |
| The homelab root certificate (Mac) | `~/.config/homelab/root_ca.crt` (stored encrypted; the homelab tooling writes it) | `chezmoi add --encrypt ~/.config/homelab/root_ca.crt`, then apply; `85-homelab-root` trusts it. After a root rotation, delete the old root in Keychain Access when the apply warns about it |
| An ssh host (name, user) for the Mac | `~/.ssh/config` (stored encrypted) | add a `Host` block to the file, then `chezmoi re-add ~/.ssh/config`; VS Code's Remote - SSH lists these. If `~/.ssh/known_hosts` changes after a first connection, run `chezmoi re-add ~/.ssh/known_hosts` |
| How long the PC idles before it sleeps | `sleep_after_minutes` | minutes; 0 means never |
| Quick access pins | `quick_access` | `shell:` names, in order |
| Repos to clone (public ones) | `repos` | cloned into `~/repos/<name>` anonymously, so no YubiKey |
| The NAS share, user, or location name | `nas` | change `host` here and `NAS_HOST` in `setup.sh` together |
| OhmGraphite settings (address, org, bucket, interval) | `ohmgraphite` | the config is rewritten and the service restarted |
| A script to run at sign-in | add `home/dot_startup/name.ps1` (or `.cmd`, `.bat`, `.vbs`, `.exe`) | `50-startup-shortcuts` makes a shortcut in `shell:startup`; add `.tmpl` to the name to use `windows.yaml` values |
| A new setup step | a new `run_after_NN-name.ps1.tmpl` in `home/.chezmoiscripts/windows/`, starting with `{{ template "ps-prelude.ps1" . }}` | scripts run in order of `NN`; make it safe to re-run |

Windows scripts are ASCII only (Windows PowerShell 5.1 reads files without a BOM as ANSI), and a startup script
runs without elevation while chezmoi's scripts run elevated.

### FanControl config

1. Save the config you like in FanControl. It lives in `FanControl\Configurations\userConfig.json` inside the
   install directory (by default `C:\Program Files (x86)\FanControl`).
2. Copy that file to `~\.config\fancontrol\userConfig.json` (create the folder).
3. First time only, `chezmoi add ~\.config\fancontrol\userConfig.json`; afterwards `re-add` it.
4. Commit and push.

On a reformat, `75-fancontrol` copies it back into FanControl (the old file is kept as `userConfig.json.bak`) and
only when the repo's copy has changed, so tweaks you make in FanControl and have not saved are not overwritten.
Restart FanControl to load it.

### Restore points (undoing a bad driver or Windows update)

`80-system-restore` turns on System Restore for `C:`, caps the space restore points may use (`system_restore.max_size`
in `windows.yaml`, 5% by default), and registers a scheduled task that creates one every day at 03:00 (or at the next
start if the PC was off). Restore points hold the changes to the registry, system files, drivers, and installed
programs, not your games or documents, so they are small and incremental. They live on the same drive and do not
protect against disk failure. Game updates change many large files, which can use up the cap and delete the oldest
points sooner; raise `max_size` if you want a longer history.

Before a risky change, such as updating the NVIDIA driver, make a restore point by hand (an elevated Windows
PowerShell; these cmdlets do not exist in PowerShell 7):

    Checkpoint-Computer -Description "before NVIDIA 5xx.xx" -RestorePointType MODIFY_SETTINGS

To see the restore points and go back to one:

    Get-ComputerRestorePoint                      # lists them with their sequence numbers
    rstrui.exe                                    # the System Restore wizard
    Restore-Computer -RestorePoint 12 -Confirm    # or go straight to restore point 12 (it restarts the PC)

If Windows will not start, the same wizard is in the Windows recovery environment (Troubleshoot > Advanced options >
System Restore). After going back, check Device Manager: a restore can leave the graphics driver in a half state, in
which case reinstall the driver you want. Device Manager's "Roll Back Driver" is another way to undo a single device.

### Drivers

Not automated. Windows Update installs working drivers for the Z790 Hero (chipset, LAN, WiFi, Bluetooth, audio),
so after a reformat run Windows Update and check Device Manager for anything with a warning. The ASUS drivers
downloaded from the board's support page (`rog.asus.com`, the ROG Maximus Z790 Hero downloads) can be installed
by hand if something is missing; they are not kept in this repo, which is public. If the network is down on a fresh
install, install the LAN driver from a USB stick first. The graphics driver comes from the NVIDIA app; keep the
installer of the last known-good version, so that a downgrade does not mean hunting for it.

### AutoHotkey scripts

They live in the `games` repo (`~/repos/games`), which `65-repos` clones; nothing else is set up for them yet.

### Run something un-elevated from an elevated session

chezmoi's scripts run elevated. To run something un-elevated, put it in `home/dot_startup/` (it runs at sign-in
without elevation, as `move-videos.ps1` does) or, from an elevated prompt,
`runas /trustlevel:0x20000 "powershell.exe -NoProfile -NoExit -File C:\path\x.ps1"`.

### Sunshine's certificate

Sunshine has one certificate for two jobs: it secures the web UI, and Moonlight remembers it when you pair. So the
script that manages it (`63-sunshine-cert`) treats it differently from every other homelab certificate. It comes
from step-ca like the rest, but through its own `sunshine` provisioner, which allows a long lifetime for
`cx4200a.lan` only: 820 days, just under the 825 days Apple accepts for any server certificate. A longer one would
bring back the Safari warning the certificate exists to remove. It must have an RSA 2048-bit key, since Sunshine
accepts nothing else. The key is made on this PC and never leaves it.

A new certificate unpairs every Moonlight client, so the script never replaces it on its own while it still works.
From 60 days before the end (`warn_days`), each apply prints the date. Renew when it suits you, in an elevated
PowerShell:

    $env:DOTFILES_RENEW_SUNSHINE = '1'; chezmoi apply --keep-going; Remove-Item Env:DOTFILES_RENEW_SUNSHINE

Then re-pair each Moonlight client (the Macs, and anything else you stream to): open Moonlight, select the PC, and
enter the PIN that Sunshine's web UI asks for under PIN. Expect to do this about every two years. The date that
counts is the earliest in the chain: the certificate stops working when the step-ca intermediate that signed it
expires, so one issued in the intermediate's last months is cut short, and the warning shows that earlier date.
An expired certificate is replaced at the next apply without the variable, since there is nothing left to keep;
re-pair afterwards.

Windows learns which root to trust from `root_fingerprint` in `windows.yaml`, because it cannot decrypt the copy in
this repo. The fingerprint is not secret (it is a hash of a public certificate), but it must be right: setup's
signature check on the repo is what stops anyone from substituting their own. After a root rotation, put the new
root's fingerprint there (`step certificate fingerprint root_ca.crt`, or the SHA-256 that `openssl x509 -noout
-fingerprint -sha256` prints, with or without colons); the next apply sees that the certificate no longer chains to
the root, requests a new one, and you re-pair.

To request a certificate, step-ca checks over ACME that this PC answers for `cx4200a.lan` on port 80, so the
script opens port 80 to the local network for the request only. Each apply also checks the live web UI against the
root, the way a browser would, and warns if the chain is incomplete. Sunshine's own certificate stays in its
`credentials` folder: to go back to it, delete the `cert` and `pkey` lines from
`C:\Program Files\Sunshine\config\sunshine.conf`, set `root_fingerprint` to empty, and restart Sunshine (then re-pair).

## Rotating passwords and tokens

None of these is in the repo, so rotating one never touches git. Each is a one-time setting that `setup.sh` skips
once it exists; to change one, set the matching `DOTFILES_FORCE_*` variable and run its script from an elevated
PowerShell (it prompts without echo).

| Secret | Where it is kept | To change it |
|---|---|---|
| Windows password (automatic sign-in) | LSA secret, written by Sysinternals Autologon | `$env:DOTFILES_FORCE_AUTOLOGON='1'; & ~\repos\chezmoi\autologin.ps1` |
| NAS password | Windows Credential Manager (target `unas`) | change it on the NAS first, then `$env:DOTFILES_FORCE_NAS='1'; & ~\repos\chezmoi\nas.ps1` |
| InfluxDB token for OhmGraphite | machine environment variable `OHMGRAPHITE_INFLUX_TOKEN` (registry, HKLM), read by the service at start | create the new token in InfluxDB, then `$env:DOTFILES_FORCE_INFLUX='1'; & ~\repos\chezmoi\ohmgraphite-token.ps1` (it restarts the service) |

Notes:

- **Leaving a secret blank.** An empty answer skips that step. Skipping the token leaves OhmGraphite installed but
  stopped; set the token later with the command above and the service starts. If the service does not see the new
  variable, reboot once.
- **Scope the token.** For OhmGraphite create an InfluxDB token that can only write to its bucket. Anything that is
  machine-wide on that PC can be read by its local administrators.
- **Unattended reformat.** All three can be piped in: `printf '%s\n%s\n%s\n' "$WINPW" "$NASPW" "$TOKEN" | COMPUTER_NAME=CX4200A bash <(curl -L sheatsley.me/setup.sh)`
  (an empty line skips one).
- **Mac secrets** are the encrypted files (`~/.config/git/repos`, `~/.ssh/known_hosts`, `~/.ssh/config`, and `~/.config/homelab/root_ca.crt`; the ssh public key is stored plain). Edit
  the file, then `chezmoi re-add <file>`; the YubiKey is needed to decrypt and encrypt.
- **A new GPG key.** Change `FINGERPRINT` in `setup.sh` (`KEY_ID` is derived from it), `$KeyId` in `setup.ps1`, republish `public.asc` and `setup.sh`, and the `recipient` in
  `home/.chezmoi.toml.tmpl`, re-encrypt the Mac secrets (`re-add` each one), and sign the commit with the new key.

## Moving OhmGraphite to a different InfluxDB

It is set up for the InfluxDB 2 exporter (`type` = `influx2`). OhmGraphite documents only an InfluxDB v1 exporter
(`influxdb`) and the v2 one; it does not mention InfluxDB 3. InfluxDB 3 accepts both the v1 `/write` API (`db`, and
the token as the password) and the v2 `/api/v2/write` API (`bucket` is the database, token in the header), so
either exporter may work against it, but this is untested. To compare it with the new database, keep this config as
the known-good reference:

1. In `windows.yaml`, change `ohmgraphite.type` and the values under it.
2. In `home/.chezmoitemplates/ohmgraphite.config`, use that exporter's keys. The OhmGraphite README lists them:
   `influxdb` (v1) uses `influx_address`, `influx_db`, `influx_user`, and `influx_password`.
3. Keep every secret out of the file: refer to a machine-wide variable as `value="%NAME%"`. A password needs its
   own variable and its own script like `ohmgraphite-token.ps1`.
4. Apply; the service restarts when the file changes.

## Testing before you publish

On a VM, run the scripts against the unpublished repo:

    $env:DOTFILES_SKIP_SYNC = '1'; $env:DOTFILES_SKIP_VERIFY = '1'; cd ~\repos\chezmoi; .\setup.ps1

`KEY_URL` points `setup.sh` at a different copy of the public key (its fingerprint must still match). `chezmoi apply --dry-run` does not run scripts.

### Testing the Mac flow in a VM

macOS guests cannot be given the YubiKey on a macOS 26 host, so a VM tests everything except the card steps
(decrypting the secrets, ssh through the card, the repo clones). Copy your working tree to `~/repos/chezmoi` in the
VM and run:

    MACHINE=mini DOTFILES_NO_YUBIKEY=1 DOTFILES_SKIP_SYNC=1 DOTFILES_SKIP_VERIFY=1 bash ~/repos/chezmoi/setup.sh

Test the card steps on the real Mac, with the old setup still available as a fallback.

## Environment variables

| Variable | Platform | Effect |
|---|---|---|
| `MACHINE` | macOS | `macbook` or `mini`; skips the "Which Mac is this" question at `chezmoi init` (asked once, then remembered in `~/.config/chezmoi/chezmoi.toml`) |
| `COMPUTER_NAME` | Windows | sets the computer name without prompting; required when `setup.sh` has no terminal to ask on a first run, and renames the PC on a re-run |
| `DOTFILES_SKIP_SYNC=1` | both | testing: use the checkout already at `~/repos/chezmoi` as it is, with no clone or pull (for trying changes before you push) |
| `DOTFILES_SKIP_VERIFY=1` | both | testing: do not require `HEAD` to carry a good signature from your key (for unsigned or uncommitted work); a warning is printed |
| `KEY_URL` | both | testing: where `setup.sh` downloads the public key from (default `https://sheatsley.me/public.asc`); the key must still match the pinned `FINGERPRINT` |
| `DOTFILES_NO_YUBIKEY=1` | macOS | testing on a machine that cannot see the YubiKey (e.g., a macOS VM): leaves out the encrypted files and skips `run_after_40-gpg-agent` and `run_after_50-repo-remote`; `run_after_60-git-repos` then skips itself because its list is encrypted. Not for real use |
| `DOTFILES_FORCE_AUTOLOGON=1` | Windows | redo automatic sign-in even if it is already enabled (asks for the password again) |
| `DOTFILES_RENEW_SUNSHINE=1` | Windows | request a new Sunshine certificate even though the current one still works (then re-pair Moonlight); see "Sunshine's certificate" |
| `DOTFILES_FORCE_NAS=1` | Windows | replace the saved NAS password |
| `DOTFILES_FORCE_INFLUX=1` | Windows | replace the OhmGraphite token |
| `NAS_HOST` | Windows | NAS whose saved password `setup.sh` looks for (default `unas`); keep equal to `nas.host` in `windows.yaml` |
| `OHM_TOKEN_VAR` | Windows | variable that holds the OhmGraphite token (default `OHMGRAPHITE_INFLUX_TOKEN`); keep equal to `ohmgraphite.token_var` |
| `GITEA_HOST` | macOS | host used for `gitea:` lines in `~/.config/git/repos` (default `gitea.lan`) |

Set them on the command line for one run (`DOTFILES_SKIP_SYNC=1 DOTFILES_SKIP_VERIFY=1 bash ~/repos/chezmoi/setup.sh`
in Git Bash or a Mac shell, or `$env:NAME = 'value'` in PowerShell, which lasts for that window).

## Troubleshooting

- **"running scripts is disabled on this system" (Windows).** A fresh Windows install refuses scripts in a normal
  PowerShell window. The `05-execution-policy` script fixes that on the next apply by setting the current user to
  `RemoteSigned` (unless a policy is already set). To run one script right now without changing anything, use
  `powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\repos\chezmoi\autologin.ps1"`.

- **Automatic sign-in fails on Windows ("Autologon did not enable autologin").** Autologon needs the account's password. For a Microsoft account that is the Microsoft account password, not the Windows Hello PIN. If the password is right and it still fails, turn off Settings > Accounts > Sign-in options > "For improved security, only allow Windows Hello sign-in for Microsoft accounts on this device" (the registry value `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device\DevicePasswordLessBuildVersion` is 2 when it is on and 0 when it is off), sign out and back in, then run `$env:DOTFILES_FORCE_AUTOLOGON='1'; & ~\repos\chezmoi\autologin.ps1` from an elevated PowerShell.

- **A Python module fails to build (macOS).** Homebrew's `python` moves to a new version each October, and a module
  without a prebuilt wheel for it is compiled from source, which needs a working Xcode command line tools install.
  The other modules are still installed, and the script names the ones that failed. Check `xcode-select -p`, update
  the tools in System Settings > Software Update (or remove and reinstall them with `sudo rm -rf
  /Library/Developer/CommandLineTools; xcode-select --install`), then apply again.

- A step failed: fix the cause and run the apply again. Finished steps are skipped, failed ones are retried.
- `chezmoi apply` stops at the first failing script unless you pass `--keep-going`.
- "HEAD is not signed": commit with `git commit -S`, or amend with `git commit -S --amend` and force-push.
- The YubiKey is not asked for on Windows during an apply, because no Windows file is encrypted.
