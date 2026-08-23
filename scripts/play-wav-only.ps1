param(
    [Parameter(Mandatory = $true)]
    [string]$SoundPath
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
$soundPlayer = New-Object System.Media.SoundPlayer
try {
    $soundPlayer.SoundLocation = $SoundPath
    $soundPlayer.Load()
    $soundPlayer.PlaySync()
} finally {
    $soundPlayer.Dispose()
}
