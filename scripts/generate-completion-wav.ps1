# Writes sounds/completion.wav — a soft classic fifth, like a singing bowl.
# 16-bit PCM / 44100 Hz so Cursor's built-in Completion Sound can play it.

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

function Add-BowlTone {
    param(
        $sampleList,
        [double]$frequencyHz,
        [double]$durationSeconds,
        [double]$toneAmplitude,
        [double]$decayRate
    )

    $sampleCount = [int]($script:sampleRate * $durationSeconds)
    $twoPi = 2.0 * [math]::PI
    $fadeInSamples = [math]::Max(1, [int]($script:sampleRate * 0.045))

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
        $waveform += 0.10 * [math]::Sin(2.0 * $phase)

        $sampleValue = $toneAmplitude * $envelope * $waveform
        if ($sampleValue -gt 0.95) { $sampleValue = 0.95 }
        if ($sampleValue -lt -0.95) { $sampleValue = -0.95 }

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

# Warm G4 then D5 (perfect fifth). Soft attack, long fade, ~1.3s.
$pcmSamples = New-Object "System.Collections.Generic.List[int16]"
Add-Silence -sampleList $pcmSamples -durationSeconds 0.08
Add-BowlTone -sampleList $pcmSamples -frequencyHz 392.00 -durationSeconds 0.42 -toneAmplitude 0.46 -decayRate 1.7
Add-Silence -sampleList $pcmSamples -durationSeconds 0.04
Add-BowlTone -sampleList $pcmSamples -frequencyHz 587.33 -durationSeconds 0.78 -toneAmplitude 0.40 -decayRate 1.5

Write-WavFile -filePath $outputPath -pcmSamples $pcmSamples
Write-Host "Wrote $outputPath"
