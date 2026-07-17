#Requires -Version 5.1
<#
.SYNOPSIS
    Applies all .reg files found in the registry folder.

.DESCRIPTION
    Iterates over every .reg file located in the "registry" folder next to this
    script and imports it using reg.exe. Requires administrator privileges.

.EXAMPLE
    .\apply_registry.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Ensure the script is running with administrator privileges.
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'This script must be run as Administrator. Please restart PowerShell with elevated privileges.'
    exit 1
}

$registryFolder = Join-Path -Path $PSScriptRoot -ChildPath 'registry'

if (-not (Test-Path -Path $registryFolder)) {
    Write-Error "Registry folder not found: $registryFolder"
    exit 1
}

$regFiles = Get-ChildItem -Path $registryFolder -Filter '*.reg' -File

if ($regFiles.Count -eq 0) {
    Write-Warning "No .reg files found in $registryFolder"
    exit 0
}

Write-Host "Found $($regFiles.Count) .reg file(s) to apply." -ForegroundColor Cyan

$failed = @()

foreach ($regFile in $regFiles) {
    Write-Host "Applying $($regFile.Name)..." -ForegroundColor Yellow
    $process = Start-Process -FilePath 'reg.exe' -ArgumentList @('import', "`"$($regFile.FullName)`"") -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Host "  Success: $($regFile.Name)" -ForegroundColor Green
    }
    else {
        Write-Host "  Failed: $($regFile.Name) (exit code $($process.ExitCode))" -ForegroundColor Red
        $failed += $regFile.Name
    }
}

Write-Host ''
if ($failed.Count -eq 0) {
    Write-Host 'All registry files applied successfully.' -ForegroundColor Green
}
else {
    Write-Warning "The following registry files failed to apply: $($failed -join ', ')"
    exit 1
}
