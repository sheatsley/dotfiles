<#
This script saves the password for the NAS account in Windows Credential
Manager, so that Windows can open the NAS share (the network location made by
55-nas-location, and the UNC path that move-videos.ps1 uses) without asking.
The host and user come from nas in home/.chezmoidata/windows.yaml. The password
is read from stdin and is never written to disk or to the repo: pipe it in, or
run this script from a normal PowerShell window to be prompted without echo
(setup.sh does the prompting when it is run from Git Bash, whose terminal
cannot hide input from PowerShell). It is a one-time setting, so the script
first checks whether a credential for the user already exists and, if so, exits
without asking; set DOTFILES_FORCE_NAS=1 to replace it, for example after
changing the password. An empty password skips the step. When stdin is
redirected, a line is always consumed, even when the step is skipped, so that
the lines of setup.sh's input stay in step: the Windows password for
autologin.ps1 comes first and the NAS password second. It is run by setup.ps1
after chezmoi has applied the repo, or on its own. It does not require an
elevated session, and it is ASCII only, since Windows PowerShell 5.1 reads
BOM-less files as ANSI.
#>
$ErrorActionPreference = 'Stop'

function Read-Password {
    <#
    This function reads the password from stdin. If stdin is redirected (a pipe
    or a file), the next line is read as it is; if it is a console, the
    password is prompted for without echo.

    :param Prompt: the text to show when prompting at a console
    :return: the password, or an empty string if there is none
    #>
    param([string]$Prompt)
    if ([Console]::IsInputRedirected) {
        $line = [Console]::In.ReadLine()
        if ($null -eq $line) { return '' }
        return $line.TrimEnd("`r", "`n")
    }
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Skip-Line {
    <#
    This function discards one line of redirected stdin, so that a skipped step
    still uses up its line.

    :return: None
    #>
    if ([Console]::IsInputRedirected) { [void][Console]::In.ReadLine() }
}

# read the NAS settings from the repo's chezmoi data
$chezmoi = Get-Command chezmoi.exe -ErrorAction SilentlyContinue
if (-not $chezmoi) { throw 'chezmoi not found.' }
$json = (& $chezmoi.Source -S $PSScriptRoot data --format json | Out-String)
$nas = ($json | ConvertFrom-Json).windows.nas
if (-not $nas -or -not $nas.host -or -not $nas.user) { throw 'No nas.host and nas.user in .chezmoidata/windows.yaml.' }
$force = ($env:DOTFILES_FORCE_NAS -eq '1')

# skip everything if a credential for this user is already saved
$saved = (cmdkey /list:$($nas.host) | Out-String)
if (-not $force -and $saved -match ('(?im)^\s*User:\s*' + [regex]::Escape($nas.user) + '\s*$')) {
    Skip-Line
    Write-Host "[nas] ok   password for $($nas.user)@$($nas.host) is saved"
    return
}

# read the password (an empty one skips this step)
$pw = Read-Password "NAS password for $($nas.user) on $($nas.host) (leave empty to skip)"
if (-not $pw) {
    Write-Warning 'No password supplied; the NAS credential was not saved.'
    return
}

# drop connections to this host from this session, since Windows allows one set of credentials per server
$old = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$stale = @((net use 2>&1 | Out-String) -split "`n" | ForEach-Object { [regex]::Matches($_, '\\\\' + [regex]::Escape($nas.host) + '\\\S+') } | ForEach-Object { $_.Value } | Sort-Object -Unique)
foreach ($unc in $stale) { net use $unc /delete /y 2>&1 | Out-Null }
$ErrorActionPreference = $old

# save the credential (it is passed as an argument, so a password containing a double quote will not survive this)
cmdkey /add:$($nas.host) /user:$($nas.user) /pass:$pw | Out-Null
$code = $LASTEXITCODE
Remove-Variable -Name pw
if ($code -ne 0) { throw "cmdkey could not save the credential (exit $code)." }
Write-Host "[nas] set  saved the password for $($nas.user)@$($nas.host)"

# check that the share answers with it
$unc = '\\' + $nas.host + '\' + $nas.share
if (Test-Path -LiteralPath $unc) {
    Write-Host "[nas] ok   $unc is reachable"
} else {
    Write-Warning "Saved the password, but $unc is not reachable from here; check the host, share, and user."
}
