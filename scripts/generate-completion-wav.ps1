# Writes sounds/completion.wav — a brief Zelda-like discovery sparkle.
# Original two-note rising chime (not a game soundtrack excerpt).

$ErrorActionPreference = "Stop"

$sampleRate = 44100
$repoRoot = Split-Path -Parent $PSScriptRoot
$soundsDirectory = Join-Path $repoRoot "sounds"
$outputPath = Join-Path $soundsDirectory "completion.wav"

function Add-Silence {
    param($sampleList, [double]$durationSeconds)
    $sampleCount = [int]($script:sampleRate * $durationSeconds)
    for ($sampleIndex = 0; $sampleIndex -lt $sampleCount; $sampleIndex++) {
        [void]$sampleList.Add([int16]0)
    }
}

function Add-CrystalTone {
    param(
        $sampleList,
        [double]$frequencyHz,
        [double]$durationSeconds,
        [double]$toneAmplitude,
        [double]$decayRate
    )

    $sampleCount = [int]($script:sampleRate * $durationSeconds)
    $twoPi = 2.0 * [math]::PI
    $fadeInSamples = [math]::Max(1, [int]($script:sampleRate * 0.006))

    for ($sampleIndex = 0; $sampleIndex -lt $sampleCount; $sampleIndex++) {
        $progress = $sampleIndex / [math]::Max($sampleCount - 1, 1)
        $attack = 1.0
        if ($sampleIndex -lt $fadeInSamples) {
            $attack = $sampleIndex / $fadeInSamples
        }

        $decay = [math]::Exp(-1.0 * $decayRate * $progress)
        $envelope = $attack * $decay

        $phase = $twoPi * $frequencyHz * $sampleIndex / $script:sampleRate
        $waveform = [math]::Sin($phase)
        $waveform += 0.38 * [math]::Sin(2.0 * $phase)
        $waveform += 0.14 * [math]::Sin(3.0 * $phase)
        $waveform += 0.08 * [math]::Sin(4.0 * $phase)

        $sampleValue = $toneAmplitude * $envelope * $waveform
        if ($sampleValue -gt 0.98) { $sampleValue = 0.98 }
        if ($sampleValue -lt -0.98) { $sampleValue = -0.98 }

        $pcmSample = [int16][math]::Round($sampleValue * 32767)
        [void]$sampleList.Add($pcmSample)
    }
}

function Write-WavFile {
    param([string]$filePath, $pcmSamples)

    $byteCount = $pcmSamples.Count * 2
    $stream = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $writer = New-Object System.IO.BinaryWriter($stream)
    try {
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
        $writer.Write([int32](36 + $byteCount))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
        $writer.Write([int32]16)
        $writer.Write([int16]1)
        $writer.Write([int16]1)
        $writer.Write([int32]$script:sampleRate)
        $writer.Write([int32]($script:sampleRate * 2))
        $writer.Write([int16]2)
        $writer.Write([int16]16)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
        $writer.Write([int32]$byteCount)
        foreach ($pcmSample in $pcmSamples) {
            $writer.Write([int16]$pcmSample)
        }
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

if (-not (Test-Path -LiteralPath $soundsDirectory)) {
    New-Item -ItemType Directory -Path $soundsDirectory | Out-Null
}

# Short rising fourth: B5 then E6, harp/bell harmonics, ~0.45s total.
$pcmSamples = New-Object "System.Collections.Generic.List[int16]"
Add-CrystalTone -sampleList $pcmSamples -frequencyHz 987.77 -durationSeconds 0.09 -toneAmplitude 0.72 -decayRate 4.2
Add-Silence -sampleList $pcmSamples -durationSeconds 0.018
Add-CrystalTone -sampleList $pcmSamples -frequencyHz 1318.51 -durationSeconds 0.34 -toneAmplitude 0.80 -decayRate 3.4

Write-WavFile -filePath $outputPath -pcmSamples $pcmSamples
Write-Host "Wrote $outputPath"
