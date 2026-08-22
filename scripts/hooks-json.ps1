# Shared writer so Windows PowerShell does not collapse one-entry hook arrays.

function ConvertTo-CursorHooksJson {
    param($config)

    function ConvertTo-HookEntryJson {
        param($hookEntry)
        $commandJson = ($hookEntry.command | ConvertTo-Json -Compress)
        $parts = @("        {", "          `"command`": $commandJson")
        if ($null -ne $hookEntry.timeout) {
            $parts += "          `"timeout`": $($hookEntry.timeout)"
        }
        if ($null -ne $hookEntry.loop_limit) {
            $parts += "          `"loop_limit`": $($hookEntry.loop_limit)"
        }
        if ($null -ne $hookEntry.failClosed) {
            $parts += "          `"failClosed`": $($hookEntry.failClosed.ToString().ToLowerInvariant())"
        }
        return $parts[0] + "`n" + ($parts[1..($parts.Length - 1)] -join ",`n") + "`n        }"
    }

    $eventNames = @($config.hooks.PSObject.Properties.Name)
    $eventBlocks = foreach ($eventName in $eventNames) {
        $entries = @($config.hooks.$eventName | Where-Object { $null -ne $_ })
        if ($entries.Count -eq 0) {
            continue
        }
        $entryJson = ($entries | ForEach-Object { ConvertTo-HookEntryJson $_ }) -join ",`n"
        "    `"$eventName`": [`n$entryJson`n    ]"
    }

    $version = if ($config.version) { [int]$config.version } else { 1 }
    if (-not $eventBlocks) {
        return "{`n  `"version`": $version,`n  `"hooks`": {}`n}`n"
    }
    return "{`n  `"version`": $version,`n  `"hooks`": {`n$($eventBlocks -join ",`n")`n  }`n}`n"
}

function Write-Utf8NoBomFile {
    param([string]$filePath, [string]$contents)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($filePath, $contents, $utf8NoBom)
}

function Remove-CompletionSoundUserHooks {
    param([string]$userHooksPath)

    if (-not (Test-Path -LiteralPath $userHooksPath)) {
        return
    }

    $hooksConfig = Get-Content -LiteralPath $userHooksPath -Raw | ConvertFrom-Json
    if (-not $hooksConfig.hooks) {
        return
    }

    foreach ($eventName in @("stop", "afterAgentResponse", "subagentStop")) {
        if (-not $hooksConfig.hooks.$eventName) {
            continue
        }
        $keptHooks = @(
            $hooksConfig.hooks.$eventName | Where-Object {
                $commandText = [string]$_.command
                $commandText -notmatch "play-completion-sound" -and $commandText -notmatch "completion-sound"
            }
        )
        $hooksConfig.hooks | Add-Member -NotePropertyName $eventName -NotePropertyValue $keptHooks -Force
    }

    Write-Utf8NoBomFile -filePath $userHooksPath -contents (ConvertTo-CursorHooksJson -config $hooksConfig)
}
