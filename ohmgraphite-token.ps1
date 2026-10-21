<#
This script stores the InfluxDB token for OhmGraphite as a machine-wide
environment variable, which is where OhmGraphite.exe.config looks for it (the
service runs as LocalSystem, which cannot see per-user variables). The variable
lives in the registry (HKLM, Session Manager\Environment), so it survives
reboots and is read each time the service starts; it is the only place the
token is kept, and it is never written to the repo. The variable name comes from
ohmgraphite.token_var in home/.chezmoidata/windows.yaml. The token is read from
stdin: pipe it in, or run this script from a normal PowerShell window to be
prompted without echo (setup.sh does the prompting when it is run from Git Bash,
whose terminal cannot hide input from PowerShell). It is a one-time setting, so
the script first checks whether the variable is already set and, if so, exits
without asking; set DOTFILES_FORCE_INFLUX=1 to replace the token, for example
after rotating it. An empty token skips the step, which leaves OhmGraphite
installed but stopped. When stdin is redirected, a line is always consumed, even
when the step is skipped, so that the lines of setup.sh's input stay in step
(the Windows password, then the NAS password, then this token). After setting the
token it starts or restarts the OhmGraphite service if it is installed. It is run
by setup.ps1 after chezmoi has applied the repo, or on its own. It requires an
elevated session (the variable is machine-wide), and it is ASCII only, since
Windows PowerShell 5.1 reads BOM-less files as ANSI.
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
    This function reads the token from stdin. If stdin is redirected (a pipe or
    a file), the next line is read as it is; if it is a console, the token is
    prompted for without echo.

    :param Prompt: the text to show when prompting at a console
    :return: the token, or an empty string if there is none
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

Assert-Admin

# read the variable name from the repo's chezmoi data
$chezmoi = Get-Command chezmoi.exe -ErrorAction SilentlyContinue
if (-not $chezmoi) { throw 'chezmoi not found.' }
$json = (& $chezmoi.Source -S $PSScriptRoot data --format json | Out-String)
$var = ($json | ConvertFrom-Json).windows.ohmgraphite.token_var
if (-not $var) { throw 'No ohmgraphite.token_var in .chezmoidata/windows.yaml.' }
$force = ($env:DOTFILES_FORCE_INFLUX -eq '1')

# skip everything if the token is already set
if (-not $force -and [Environment]::GetEnvironmentVariable($var, 'Machine')) {
    Skip-Line
    Write-Host "[influx] ok   $var is set"
    return
}

# read the token (an empty one skips this step)
$token = Read-Password "InfluxDB token for OhmGraphite (leave empty to skip)"
if (-not $token) {
    Write-Warning "No token supplied; $var was not set and OhmGraphite stays stopped."
    return
}

# set it machine-wide (this also tells running programs that the environment changed)
[Environment]::SetEnvironmentVariable($var, $token, 'Machine')
$check = [Environment]::GetEnvironmentVariable($var, 'Machine')
Remove-Variable -Name token
if (-not $check) { throw "Could not set $var." }
Write-Host "[influx] set  $var"

# make the service pick it up
$svc = Get-Service -Name 'OhmGraphite' -ErrorAction SilentlyContinue
if ($svc) {
    Restart-Service -Name 'OhmGraphite'
    Write-Host '[influx] set  restarted the OhmGraphite service'
} else {
    Write-Host '[influx] ok   the OhmGraphite service is not installed yet; it will start at the next apply'
}
