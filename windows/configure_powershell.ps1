$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Locate Windows Terminal settings.json
# ------------------------------------------------------------

$terminalPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)

$settingsPath = $terminalPaths |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1

if (-not $settingsPath) {
    throw "Windows Terminal settings.json was not found. Open Windows Terminal once, then run this script again."
}

Write-Host "Windows Terminal settings:"
Write-Host $settingsPath
Write-Host

# ------------------------------------------------------------
# Back up Windows Terminal settings
# ------------------------------------------------------------

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$settingsBackup = "$settingsPath.backup-$timestamp"

Copy-Item -LiteralPath $settingsPath -Destination $settingsBackup -Force

$content = Get-Content -LiteralPath $settingsPath -Raw

# ------------------------------------------------------------
# Build missing Windows Terminal shortcuts
# ------------------------------------------------------------

$actionsToAdd = @()

if ($content -notmatch '"keys"\s*:\s*"ctrl\+pgup"') {
    $actionsToAdd += @'
        {
            "command": "nextTab",
            "keys": "ctrl+pgup"
        }
'@
}

if ($content -notmatch '"keys"\s*:\s*"ctrl\+pgdn"') {
    $actionsToAdd += @'
        {
            "command": "prevTab",
            "keys": "ctrl+pgdn"
        }
'@
}

if ($content -notmatch '"keys"\s*:\s*"ctrl\+t"') {
    $actionsToAdd += @'
        {
            "command": "duplicateTab",
            "keys": "ctrl+t"
        }
'@
}

if ($content -notmatch '"keys"\s*:\s*"ctrl\+shift\+t"') {
    $actionsToAdd += @'
        {
            "command": "duplicateTab",
            "keys": "ctrl+shift+t"
        }
'@
}

if ($actionsToAdd.Count -gt 0) {
    $newActions = $actionsToAdd -join ",`r`n"

    if ($content -match '"actions"\s*:\s*\[') {
        $actionsPattern = '("actions"\s*:\s*\[)(?<space>\s*)(?<next>[^\s\]])?'

        $content = [regex]::Replace(
            $content,
            $actionsPattern,
            {
                param($match)

                $prefix = $match.Groups[1].Value
                $space = $match.Groups["space"].Value
                $nextCharacter = $match.Groups["next"].Value

                if ($nextCharacter) {
                    return $prefix +
                        "`r`n" +
                        $newActions +
                        ",`r`n" +
                        $space +
                        $nextCharacter
                }

                return $prefix +
                    "`r`n" +
                    $newActions +
                    "`r`n" +
                    $space
            },
            1
        )
    }
    else {
        $actionsSection = @"
{
    "actions":
    [
$newActions
    ],
"@

        $content = [regex]::Replace(
            $content,
            '^\s*\{',
            $actionsSection,
            1
        )
    }

    Set-Content -LiteralPath $settingsPath -Value $content -Encoding utf8

    Write-Host "Windows Terminal shortcuts added."
}
else {
    Write-Host "Windows Terminal shortcuts already exist."
}

# ------------------------------------------------------------
# Configure PowerShell current-directory reporting
# ------------------------------------------------------------

$startMarker = "# BEGIN WINDOWS TERMINAL SAME DIRECTORY"
$endMarker = "# END WINDOWS TERMINAL SAME DIRECTORY"

$profileBlock = @'

# BEGIN WINDOWS TERMINAL SAME DIRECTORY

# Preserve the prompt that was configured before this block.
$script:WindowsTerminalOriginalPrompt = ${function:prompt}

function global:prompt {
    $currentLocation = $ExecutionContext.SessionState.Path.CurrentLocation

    # Report the current working directory to Windows Terminal (OSC 9;9)
    # so that "new tab" / "duplicate tab" opens in the same folder.
    $cwdSequence = ""
    if ($currentLocation.Provider.Name -eq "FileSystem") {
        $escape = [char]27
        $cwdSequence = "$escape]9;9;`"$($currentLocation.ProviderPath)`"$escape\"
    }

    if ($script:WindowsTerminalOriginalPrompt) {
        $basePrompt = & $script:WindowsTerminalOriginalPrompt
    }
    else {
        $basePrompt = "PS $currentLocation$('>' * ($nestedPromptLevel + 1)) "
    }

    return $cwdSequence + ($basePrompt -join "")
}

# END WINDOWS TERMINAL SAME DIRECTORY
'@

# Configure BOTH Windows PowerShell 5.1 and PowerShell 7 profiles so that
# the reporting works regardless of which shell Windows Terminal launches.
$documents = [Environment]::GetFolderPath('MyDocuments')
$profilePaths = @(
    (Join-Path $documents 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1')
) | Select-Object -Unique

foreach ($profilePath in $profilePaths) {
    if (-not (Test-Path -LiteralPath $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $profileContent = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue

    if ([string]::IsNullOrEmpty($profileContent) -or $profileContent -notmatch [regex]::Escape($startMarker)) {
        if ((Test-Path -LiteralPath $profilePath) -and $profileContent) {
            Copy-Item -LiteralPath $profilePath -Destination "$profilePath.backup-$timestamp" -Force
        }

        Add-Content -LiteralPath $profilePath -Value $profileBlock -Encoding utf8

        Write-Host "PowerShell profile updated:"
        Write-Host "  $profilePath"
    }
    else {
        Write-Host "Already configured: $profilePath"
    }
}

Write-Host
Write-Host "Configuration completed successfully."
Write-Host
Write-Host "Shortcuts:"
Write-Host "  Ctrl+Page Up   -> Next tab"
Write-Host "  Ctrl+Page Down -> Previous tab"
Write-Host "  Ctrl+T         -> New tab in the same folder"
Write-Host
Write-Host "Restart Windows Terminal to activate all changes."
Write-Host "Settings backup: $settingsBackup"