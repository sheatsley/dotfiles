<#
This script enables automatic sign-in (item 6 on the initialization list) with
Sysinternals Autologon, which stores the password as an LSA secret rather than
as plaintext in the registry. The password is read from stdin and is never
written to disk or to the repo: pipe it in, or run this script from a normal
elevated PowerShell window to be prompted without echo (setup.sh does the
prompting when it is run from Git Bash, whose terminal cannot hide input from
PowerShell). Autologin only needs to be configured once, so the script first
checks whether it is already enabled for this user and, if so, exits without
reading a password; set DOTFILES_FORCE_AUTOLOGON=1 to redo it, for example after
changing the password. An empty password skips the step. When stdin is redirected, a line is always
consumed, even when the step is skipped, so that the lines of setup.sh's input
stay in step (this password first, the NAS password of nas.ps1 second). It is
run by setup.ps1
after chezmoi has applied the repo, or on its own. It requires an elevated
session, and it is ASCII only, since Windows PowerShell 5.1 reads BOM-less files
as ANSI.
#>
$ErrorActionPreference = 'Stop'

function Assert-Admin {
    <#
    This function stops the script with a clear message if the session is not
    elevated, rather than letting it fail later with a permissions error.

    :return: None
    #>
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This step needs an elevated session. Re-run from an Administrator Git Bash or PowerShell.'
    }
}

function Read-Password {
    <#
    This function reads the password from stdin. If stdin is redirected (a pipe
    or a file), the first line is read as it is; if it is a console, the
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
    still uses up its line (setup.sh sends the Windows password first and the
    NAS password second).

    :return: None
    #>
    if ([Console]::IsInputRedirected) { [void][Console]::In.ReadLine() }
}

function Find-Autologon {
    <#
    This function searches the winget package folders for the Autologon
    executable, preferring the 64-bit build.

    :return: the full path to the executable, or nothing if it is not installed
    #>
    $roots = @("$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:ProgramFiles\WinGet\Packages")
    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $hit = Get-ChildItem -Path $r -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -in @('Autologon64.exe', 'Autologon.exe') } |
            Sort-Object { $_.Name -ne 'Autologon64.exe' } |
            Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

Assert-Admin

$user   = $env:USERNAME
$domain = $env:USERDOMAIN
$wl     = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$force  = ($env:DOTFILES_FORCE_AUTOLOGON -eq '1')

# skip everything if autologin is already enabled for this user
$cur = Get-ItemProperty -LiteralPath $wl
if (-not $force -and $cur.AutoAdminLogon -eq '1' -and $cur.DefaultUserName -eq $user) {
    Skip-Line
    Write-Host "[autologin] ok   already enabled for $user"
    return
}

# read the password (an empty one skips this step)
$pw = Read-Password "Windows password for $user (a Microsoft account's password, not the PIN; leave empty to skip)"
if (-not $pw) {
    Write-Warning 'No password supplied; automatic sign-in was not configured.'
    return
}

# install Autologon if it is missing
$exe = Find-Autologon
if (-not $exe) {
    Write-Host '[autologin] installing Sysinternals Autologon via winget'
    winget install --id Microsoft.Sysinternals.Autologon --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget could not install Autologon (exit $LASTEXITCODE)." }
    $exe = Find-Autologon
}
if (-not $exe) { throw 'Autologon was installed but its executable could not be located.' }

# run Autologon (a GUI-subsystem program, so wait for it explicitly)
# each argument is quoted, so a password containing a double quote will not survive this
$argList = @("`"$user`"", "`"$domain`"", "`"$pw`"", '/accepteula')
$proc = Start-Process -FilePath $exe -ArgumentList $argList -Wait -PassThru
Remove-Variable -Name pw
Remove-Variable -Name argList

# verify the result in the registry rather than trusting the exit code
$after = Get-ItemProperty -LiteralPath $wl
if ($after.AutoAdminLogon -ne '1' -or $after.DefaultUserName -ne $user) {
    throw "Autologon did not enable autologin (exit $($proc.ExitCode)). Autologon needs the account's password; for a Microsoft account that is its password, not the Windows Hello PIN. If the password is right and this still fails, turn off Settings > Accounts > Sign-in options > 'For improved security, only allow Windows Hello sign-in for Microsoft accounts on this device', sign out and back in, and run this again with DOTFILES_FORCE_AUTOLOGON=1."
}
Write-Host "[autologin] set  enabled for $user"
