# Writes sounds/long-completion.wav — an original 8s resolution phrase.
# 16-bit PCM / 44100 Hz. Not a licensed track.

$ErrorActionPreference = "Stop"

$sampleRate = 44100
$repoRoot = Split-Path -Parent $PSScriptRoot
$soundsDirectory = Join-Path $repoRoot "sounds"
$outputPath = Join-Path $soundsDirectory "long-completion.wav"
$clipDurationSeconds = 8.0

function Get-NoteFrequencyHz {
    param([int]$midiNote)
    return 440.0 * [math]::Pow(2.0, ($midiNote - 69) / 12.0)
}

function Add-MixedTone {
    param(
        $sampleBuffer,
        [int]$startSample,
        [double]$frequencyHz,
        [double]$durationSeconds,
        [double]$toneAmplitude,
        [double]$decayRate
    )

    $toneSampleCount = [int]($script:sampleRate * $durationSeconds)
    $twoPi = 2.0 * [math]::PI
    $fadeInSamples = [math]::Max(1, [int]($script:sampleRate * 0.02))
    $fadeOutSamples = [math]::Max(1, [int]($script:sampleRate * 0.08))

    for ($sampleIndex = 0; $sampleIndex -lt $toneSampleCount; $sampleIndex++) {
        $bufferIndex = $startSample + $sampleIndex
        if ($bufferIndex -ge $sampleBuffer.Count) {
            break
        }

        $progress = $sampleIndex / [math]::Max($toneSampleCount - 1, 1)
        $attack = 1.0
        if ($sampleIndex -lt $fadeInSamples) {
            $attack = $sampleIndex / $fadeInSamples
        }
        $release = 1.0
        $samplesRemaining = $toneSampleCount - $sampleIndex
        if ($samplesRemaining -lt $fadeOutSamples) {
            $release = $samplesRemaining / $fadeOutSamples
        }

        $envelope = $attack * $release * [math]::Exp(-1.0 * $decayRate * $progress)
        $phase = $twoPi * $frequencyHz * $sampleIndex / $script:sampleRate
        $waveform = [math]::Sin($phase)
        $waveform += 0.18 * [math]::Sin(2.0 * $phase)
        $waveform += 0.06 * [math]::Sin(3.0 * $phase)

        $sampleBuffer[$bufferIndex] += $toneAmplitude * $envelope * $waveform
    }
}

if (-not (Test-Path -LiteralPath $soundsDirectory)) {
    New-Item -ItemType Directory -Path $soundsDirectory | Out-Null
}

$totalSamples = [int]($sampleRate * $clipDurationSeconds)
$sampleBuffer = New-Object "double[]" $totalSamples

# Soft tonic drone under an original rising-then-resolving phrase.
Add-MixedTone -sampleBuffer $sampleBuffer -startSample 0 -frequencyHz (Get-NoteFrequencyHz 48) -durationSeconds 8.0 -toneAmplitude 0.10 -decayRate 0.35
Add-MixedTone -sampleBuffer $sampleBuffer -startSample 0 -frequencyHz (Get-NoteFrequencyHz 55) -durationSeconds 8.0 -toneAmplitude 0.07 -decayRate 0.40

$melody = @(
    @{ Midi = 60; StartSeconds = 0.15; DurationSeconds = 0.70; Amplitude = 0.42 }
    @{ Midi = 64; StartSeconds = 0.80; DurationSeconds = 0.70; Amplitude = 0.44 }
    @{ Midi = 67; StartSeconds = 1.45; DurationSeconds = 0.70; Amplitude = 0.46 }
    @{ Midi = 72; StartSeconds = 2.10; DurationSeconds = 1.10; Amplitude = 0.48 }
    @{ Midi = 71; StartSeconds = 3.15; DurationSeconds = 0.55; Amplitude = 0.40 }
    @{ Midi = 69; StartSeconds = 3.65; DurationSeconds = 0.70; Amplitude = 0.42 }
    @{ Midi = 67; StartSeconds = 4.30; DurationSeconds = 0.80; Amplitude = 0.44 }
    @{ Midi = 64; StartSeconds = 5.05; DurationSeconds = 0.80; Amplitude = 0.40 }
    @{ Midi = 67; StartSeconds = 5.80; DurationSeconds = 0.70; Amplitude = 0.42 }
    @{ Midi = 72; StartSeconds = 6.40; DurationSeconds = 1.50; Amplitude = 0.50 }
)

foreach ($note in $melody) {
    $startSample = [int]($sampleRate * $note.StartSeconds)
    Add-MixedTone -sampleBuffer $sampleBuffer -startSample $startSample -frequencyHz (Get-NoteFrequencyHz $note.Midi) -durationSeconds $note.DurationSeconds -toneAmplitude $note.Amplitude -decayRate 1.15
}

$pcmSamples = New-Object "System.Collections.Generic.List[int16]"
for ($sampleIndex = 0; $sampleIndex -lt $totalSamples; $sampleIndex++) {
    $mixed = $sampleBuffer[$sampleIndex]
    if ($mixed -gt 0.95) { $mixed = 0.95 }
    if ($mixed -lt -0.95) { $mixed = -0.95 }
    [void]$pcmSamples.Add([int16][math]::Round($mixed * 32767))
}

$byteCount = $pcmSamples.Count * 2
$stream = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
$writer = New-Object System.IO.BinaryWriter($stream)
try {
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $writer.Write([int32](36 + $byteCount))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $writer.Write([int32]16)
    $writer.Write([int16]1)
    $writer.Write([int16]1)
    $writer.Write([int32]$sampleRate)
    $writer.Write([int32]($sampleRate * 2))
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

Write-Host "Wrote $outputPath ($clipDurationSeconds s)"
