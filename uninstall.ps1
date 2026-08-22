# Removes the local plugin and any leftover user-hook copies.
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "scripts\hooks-json.ps1")

$cursorHome = Join-Path $env:USERPROFILE ".cursor"
$pluginInstallDirectory = Join-Path $cursorHome "plugins\local\completion-sound"
$userHooksPath = Join-Path $cursorHome "hooks.json"
$legacyHookFiles = @(
    (Join-Path $cursorHome "hooks\play-completion-sound.ps1"),
    (Join-Path $cursorHome "hooks\play-completion-sound.cmd"),
    (Join-Path $cursorHome "hooks\completion.wav"),
    (Join-Path $cursorHome "hooks\completion-sound")
)

if (Test-Path -LiteralPath $pluginInstallDirectory) {
    Remove-Item -LiteralPath $pluginInstallDirectory -Recurse -Force
}

foreach ($legacyPath in $legacyHookFiles) {
    if (Test-Path -LiteralPath $legacyPath) {
        Remove-Item -LiteralPath $legacyPath -Recurse -Force
    }
}

Remove-CompletionSoundUserHooks -userHooksPath $userHooksPath

Write-Output "Removed completion-sound plugin and leftover user hooks from $cursorHome"
