# Fallback: user-level ~/.cursor/hooks.json. Removes the local plugin first
# so plugin hooks and user hooks cannot both fire.
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "hooks-json.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
$bundledPlayer = Join-Path $PSScriptRoot "play-completion-sound.ps1"
$bundledCmd = Join-Path $PSScriptRoot "play-completion-sound.cmd"
$bundledSound = Join-Path $repoRoot "sounds\completion.wav"
$cursorDirectory = Join-Path $env:USERPROFILE ".cursor"
$hooksDirectory = Join-Path $cursorDirectory "hooks"
$userHooksPath = Join-Path $cursorDirectory "hooks.json"
$installedPlayer = Join-Path $hooksDirectory "play-completion-sound.ps1"
$installedCmd = Join-Path $hooksDirectory "play-completion-sound.cmd"
$installedSound = Join-Path $hooksDirectory "completion.wav"
$pluginInstallDirectory = Join-Path $cursorDirectory "plugins\local\completion-sound"
$hookCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./hooks/play-completion-sound.ps1"'
$playerMarker = "play-completion-sound.ps1"

if (-not (Test-Path -LiteralPath $bundledSound)) {
    & (Join-Path $PSScriptRoot "generate-completion-wav.ps1")
}

if (Test-Path -LiteralPath $pluginInstallDirectory) {
    Remove-Item -LiteralPath $pluginInstallDirectory -Recurse -Force
}

if (-not (Test-Path -LiteralPath $hooksDirectory)) {
    New-Item -ItemType Directory -Path $hooksDirectory -Force | Out-Null
}

Copy-Item -LiteralPath $bundledPlayer -Destination $installedPlayer -Force
if (Test-Path -LiteralPath $bundledCmd) {
    Copy-Item -LiteralPath $bundledCmd -Destination $installedCmd -Force
}
Copy-Item -LiteralPath $bundledSound -Destination $installedSound -Force

$hookEntry = [pscustomobject]@{
    command = $hookCommand
    timeout = 8
}

function Remove-ExistingPlayerHooks {
    param($eventHooks)
    if ($null -eq $eventHooks) {
        return @()
    }
    return @($eventHooks | Where-Object { $_.command -notmatch [regex]::Escape($playerMarker) })
}

if (Test-Path -LiteralPath $userHooksPath) {
    $hooksConfig = Get-Content -LiteralPath $userHooksPath -Raw | ConvertFrom-Json
} else {
    $hooksConfig = [pscustomobject]@{
        version = 1
        hooks   = [pscustomobject]@{}
    }
}

if (-not $hooksConfig.version) {
    $hooksConfig | Add-Member -NotePropertyName version -NotePropertyValue 1
}
if (-not $hooksConfig.hooks) {
    $hooksConfig | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}

foreach ($eventName in @("stop", "afterAgentResponse", "subagentStop")) {
    $eventHooks = Remove-ExistingPlayerHooks -eventHooks $hooksConfig.hooks.$eventName
    $eventHooks += $hookEntry
    $hooksConfig.hooks | Add-Member -NotePropertyName $eventName -NotePropertyValue @($eventHooks) -Force
}

Write-Utf8NoBomFile -filePath $userHooksPath -contents (ConvertTo-CursorHooksJson -config $hooksConfig)

Write-Host "Installed user hook fallback (plugin copy removed): $userHooksPath"
Write-Host "Prefer npm run install-plugin unless this fallback is required."
