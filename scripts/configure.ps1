# Opens the user settings file in the default editor.
$ErrorActionPreference = "Stop"

$userSettingsPath = & (Join-Path $PSScriptRoot "write-user-settings.ps1")
Invoke-Item -LiteralPath $userSettingsPath
Write-Host "Edit and save. Cursor picks this up on the next hook run (no reinstall)."
