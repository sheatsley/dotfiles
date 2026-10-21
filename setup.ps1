<#
This script bootstraps a Windows machine from
https://github.com/sheatsley/dotfiles. It is launched by setup.sh (from an
elevated Git Bash) or run directly from an elevated Windows PowerShell. The
following tasks are performed (if necessary):

    1. Check for administrator rights, winget, and git
    2. Install chezmoi and Gpg4win
    3. Add the public key (stored on the YubiKey) to Gpg4win's keyring with
       ultimate trust (setup.sh has already verified the clone with Git's gpg
       against a pinned fingerprint; this is a second check)
    4. Clone/pull the dotfiles repo to ~\repos\chezmoi
    5. Verify that HEAD is signed by that key
    6. Generate the chezmoi config and apply the repo
    7. Enable automatic sign-in (autologin.ps1), save the NAS password
       (nas.ps1), and set the OhmGraphite token (ohmgraphite-token.ps1); each
       reads a line of stdin (in that order) and skips its step if it is already
       done

Every task probes the system before changing it, so re-running this script
after an error (e.g., a network failure) is safe. The following environment
variables are optional: COMPUTER_NAME skips the computer name prompt,
DOTFILES_SKIP_SYNC=1 uses the local repo as-is without fetching (for testing
before pushing), and DOTFILES_SKIP_VERIFY=1 skips the signature check (for
testing with unsigned commits), DOTFILES_FORCE_AUTOLOGON=1 redoes autologin even
if it is already enabled, and DOTFILES_FORCE_NAS=1 and DOTFILES_FORCE_INFLUX=1
do the same for the NAS password and the OhmGraphite token. It is ASCII only, since Windows PowerShell 5.1
reads BOM-less files as ANSI.
#>
$ErrorActionPreference = 'Stop'

$Repo  = 'sheatsley/dotfiles'
$KeyId = '1A2405C9E6BFBE34'
$Src   = Join-Path $HOME 'repos\chezmoi'

function Step {
    <#
    This function prints a highlighted heading for the task that is starting.

    :param Message: the text to print
    :return: None
    #>
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Exec {
    <#
    This function runs a native command and stops the script if it fails.
    PowerShell does not treat a non-zero exit code from a native command as an
    error by itself.

    :param Exe: the program to run
    :param Arguments: the arguments to pass to it
    :return: None
    #>
    param([string]$Exe, [string[]]$Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "'$Exe $($Arguments -join ' ')' failed (exit $LASTEXITCODE)" }
}

function Invoke-Native {
    <#
    This function runs a native command and captures its output and exit code
    without stopping the script when it fails. Under $ErrorActionPreference =
    'Stop', Windows PowerShell 5.1 turns redirected native stderr into
    terminating errors, so the preference is relaxed while the command runs.

    :param Exe: the program to run
    :param Arguments: the arguments to pass to it
    :param InputText: text to send to the program on stdin (optional)
    :return: an object with the combined Output (stdout and stderr) and ExitCode
    #>
    param([string]$Exe, [string[]]$Arguments, [string]$InputText)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($InputText) {
            $lines = $InputText | & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
        } else {
            $lines = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
        }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $old
    }
    return [pscustomobject]@{ Output = (@($lines) -join "`n"); ExitCode = $code }
}

function Update-SessionPath {
    <#
    This function rebuilds PATH from the registry. This picks up programs that
    winget just installed, and it drops the MSYS paths (/usr/bin and friends)
    that Git Bash injects, so that "gpg" cannot resolve to Git's own gpg.

    :return: None
    #>
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = [Environment]::ExpandEnvironmentVariables("$machine;$user")
}

function Find-Gpg {
    <#
    This function locates the gpg that ships with Gpg4win (the one that can
    talk to the YubiKey) in either Program Files location.

    :return: the full path to gpg.exe, or nothing if Gpg4win is not installed
    #>
    foreach ($p in @("${env:ProgramFiles(x86)}\GnuPG\bin\gpg.exe", "$env:ProgramFiles\GnuPG\bin\gpg.exe")) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Install-Winget {
    <#
    This function installs a package with winget (non-interactively) and then
    refreshes PATH so that the new program can be used immediately.

    :param Id: the winget package identifier
    :return: None
    #>
    param([string]$Id)
    Exec 'winget' @('install', '--id', $Id, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements')
    Update-SessionPath
}

function Test-KeyTrusted {
    <#
    This function checks whether the public key is in the keyring with ultimate
    trust. It reads $Gpg and $KeyId from the script scope.

    :return: True if the key is present and ultimately trusted
    #>
    $r = Invoke-Native $Gpg @('--with-colons', '--list-keys', $KeyId)
    if ($r.ExitCode -ne 0) { return $false }
    $pub = $r.Output -split "`n" | Where-Object { $_ -like 'pub:*' } | Select-Object -First 1
    return [bool]($pub -and $pub.Split(':')[8] -eq 'u')
}

# check that the session is elevated and that git and winget are available
Step 'Checking prerequisites'
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this from an elevated session (Git Bash or PowerShell started with "Run as administrator").'
}
Update-SessionPath
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'winget not found. Install "App Installer" from the Microsoft Store.' }
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { throw 'git not found. Run: winget install Git.Git' }
$git = (Get-Command git.exe).Source

# install chezmoi and Gpg4win if they are missing
if (-not (Get-Command chezmoi.exe -ErrorAction SilentlyContinue)) { Step 'Installing chezmoi'; Install-Winget 'twpayne.chezmoi' }
$Gpg = Find-Gpg
if (-not $Gpg) { Step 'Installing Gpg4win'; Install-Winget 'GnuPG.Gpg4win'; $Gpg = Find-Gpg }
if (-not $Gpg) { throw 'Gpg4win installed but gpg.exe was not found.' }
$cz = (Get-Command chezmoi.exe).Source

# add the public key to the keyring and trust it (a port of public_key in the macOS bootstrap)
if (Test-KeyTrusted) {
    Step "Key $KeyId already trusted"
} else {
    # fetch the key from the URL stored on the card
    Step "Importing $KeyId from the URL stored on the YubiKey"
    $card = Invoke-Native $Gpg @('--card-status')
    if ($card.ExitCode -ne 0) { throw "gpg cannot see the YubiKey:`n$($card.Output)" }
    $m = [regex]::Match($card.Output, 'URL of public key\s*:\s*(https?://\S+)')
    if (-not $m.Success) { throw 'No public-key URL is stored on the card (see gpg --card-status).' }
    $f = Invoke-Native $Gpg @('--fetch-key', $m.Groups[1].Value)
    if ($f.ExitCode -ne 0) { throw "gpg --fetch-key failed:`n$($f.Output)" }

    # set ultimate trust (6) on the fingerprint; ${fpr} needs braces since "$fpr:6" would parse as a scoped variable
    $fp = Invoke-Native $Gpg @('--with-colons', '--fingerprint', $KeyId)
    $fprLine = $fp.Output -split "`n" | Where-Object { $_ -like 'fpr:*' } | Select-Object -First 1
    if (-not $fprLine) { throw "Could not read the fingerprint for $KeyId." }
    $fpr = $fprLine.Split(':')[9].Trim()
    if ($fpr -notmatch '^[0-9A-Fa-f]{40,64}$') { throw "Unexpected fingerprint '$fpr' (from line '$fprLine')." }

    # hand gpg the trust line in a file (ASCII, LF) rather than stdin, since piping text to a native
    # command in Windows PowerShell can alter the bytes gpg receives
    $trustFile = Join-Path ([IO.Path]::GetTempPath()) "ownertrust-$PID.txt"
    [IO.File]::WriteAllText($trustFile, "${fpr}:6:`n", [Text.Encoding]::ASCII)
    try {
        $t = Invoke-Native $Gpg @('--import-ownertrust', $trustFile)
    } finally {
        Remove-Item -LiteralPath $trustFile -Force -ErrorAction SilentlyContinue
    }
    if ($t.ExitCode -ne 0 -or -not (Test-KeyTrusted)) { throw "Could not set ultimate trust on $KeyId (fingerprint $fpr).`n$($t.Output)" }
}

# clone the repo (or fast-forward an existing clone)
Step "Syncing dotfiles ($Repo)"
if ($env:DOTFILES_SKIP_SYNC -eq '1') {
    Write-Warning 'Skipping sync (DOTFILES_SKIP_SYNC=1); using the repo as it is.'
} elseif (-not (Test-Path -LiteralPath (Join-Path $Src '.git'))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Src) | Out-Null
    Exec $git @('clone', "https://github.com/$Repo.git", $Src)
} else {
    Exec $git @('-C', $Src, 'pull', '--ff-only')
}

# refuse to run anything unless HEAD carries a good signature from the trusted key
if ($env:DOTFILES_SKIP_VERIFY -eq '1') {
    Write-Warning 'Skipping signature verification (DOTFILES_SKIP_VERIFY=1).'
} else {
    # git must use Gpg4win's gpg; %G? prints G for a good signature from a trusted key
    Step 'Verifying the signature on HEAD'
    $v = Invoke-Native $git @('-c', "gpg.program=$Gpg", '-C', $Src, 'log', '-1', '--format=%G?', 'HEAD')
    $status = ($v.Output -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)
    if ($status) { $status = $status.Trim() }
    if ($status -ne 'G') {
        throw "HEAD is not signed by a trusted key (git status '$status'). Refusing to apply."
    }
}

# generate the chezmoi config (COMPUTER_NAME, if set, is read by .chezmoi.toml.tmpl)
Step 'Configuring chezmoi'
Exec $cz @('-S', $Src, 'init')

# apply the repo; a failing script does not stop the others
Step 'Applying'
& $cz -S $Src apply --keep-going
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Warning "chezmoi apply finished with errors (exit $code). Fix the cause and re-run; finished steps will be skipped."
}

# enable automatic sign-in, save the NAS password, and set the OhmGraphite token; each reads stdin (they run in
# this session, so they share it) and skip their step if it is already done
$secretsFailed = $false
foreach ($name in @('autologin.ps1', 'nas.ps1', 'ohmgraphite-token.ps1')) {
    Step "Running $name"
    try {
        & (Join-Path $Src $name)
    } catch {
        Write-Warning "$name failed: $($_.Exception.Message)"
        $secretsFailed = $true
    }
}

if ($code -ne 0 -or $secretsFailed) { exit 1 }
Step 'Done. If a script reported "Reboot required", restart Windows.'
