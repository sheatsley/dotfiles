<#
This file defines the helpers shared by the Windows scripts in
.chezmoiscripts/windows. chezmoi pastes it at the top of each of those scripts
(through the template directive on their first line), so every script is
self-contained when it runs. Do not put template braces in this file, since it
would then include itself. It is ASCII only, since Windows PowerShell 5.1 reads
BOM-less files as ANSI and mangles anything else.
#>
$ErrorActionPreference = 'Stop'

function Write-Step {
    <#
    This function prints a timestamped progress line so that the output of a
    long apply is easy to follow (and audit afterwards).

    :param Message: the text to print
    :return: None
    #>
    param([string]$Message)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message)
}

function Test-Admin {
    <#
    This function checks whether the current session is elevated, which is
    required to change machine-wide settings (HKLM, the network stack, services).

    :return: True if the session is running as an administrator
    #>
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin {
    <#
    This function stops the calling script with a clear message if the session
    is not elevated, rather than letting it fail halfway through with a
    permissions error.

    :return: None
    #>
    if (-not (Test-Admin)) {
        throw 'This step needs an elevated session. Re-run from an Administrator Git Bash or PowerShell.'
    }
}

function Set-RegValue {
    <#
    This function sets a registry value idempotently: it creates the key if it
    is missing and only writes the value when it differs from the current one.
    Callers that do not care whether anything changed pipe the result to
    Out-Null.

    :param Path: the registry key (e.g., HKCU:\Control Panel\Keyboard)
    :param Name: the name of the value to set
    :param Value: the desired value
    :param Type: the registry value type (defaults to DWord)
    :return: True if the value was changed, otherwise False
    #>
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWord'
    )

    # create the key if it is missing
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    # leave the value alone if it is already correct
    $current = (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($null -ne $current -and "$current" -eq "$Value") {
        Write-Step "ok   $Name = $Value"
        return $false
    }
    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    Write-Step "set  $Name = $Value (was: $current)"
    return $true
}
