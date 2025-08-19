function Set-CueFileStructure {
    param (
        [Parameter(Mandatory=$true)] [string]$CueFilePath,
        [switch]$WriteChanges
    )

    $lines = Get-Content -LiteralPath $CueFilePath
    $reFile = '^\s*FILE\s+"(.+?)"\s+\w+'
    $reTrack = '^\s*TRACK\s+([0-9]+)\s+\w+'
    $reIndex0 = '^\s*INDEX\s+00\s+'
    $reIndex1 = '^\s*INDEX\s+01\s+'
    $reMeta = '^\s*(TITLE|PERFORMER|FLAGS|PREGAP)\b'
    $reHeader = '^\s*(REM|GENRE|DATE|DISCID|COMMENT|TITLE|PERFORMER)\b'

    $header = [System.Collections.ArrayList]::new()
    $fileBlocks = [System.Collections.ArrayList]::new()
    $currentFile = $null
    $trackBuffer = $null
    $insideTrack = $false

    foreach ($line in $lines) {
        # If we encounter a new FILE while inside a track, finalize the track first
        if ($insideTrack -and $line -match $reFile) {
            # ensure trackBuffer has an INDEX 01
            if ($trackBuffer -and -not ($trackBuffer -join "`n" -match $reIndex1)) {
                $trackBuffer.Add("    INDEX 01 00:00:00") | Out-Null
            }
            if ($null -ne $currentFile) { $currentFile.Tracks.Add($trackBuffer) | Out-Null }
            $trackBuffer = $null
            $insideTrack = $false
        }

        if ($line -match $reHeader -and $null -eq $currentFile -and -not $insideTrack) {
            $header.Add($line) | Out-Null
            continue
        }

        if ($line -match $reFile) {
            $currentFile = [PSCustomObject]@{
                FileLine = $line
                Tracks   = [System.Collections.ArrayList]::new()
            }
            $fileBlocks.Add($currentFile) | Out-Null
            continue
        }

        if ($line -match $reTrack) {
            $trackBuffer = [System.Collections.ArrayList]::new()
            $trackBuffer.Add($line) | Out-Null
            $insideTrack = $true
            continue
        }

        if ($insideTrack -and $line -match $reMeta) {
            $trackBuffer.Add($line) | Out-Null
            continue
        }

        if ($insideTrack -and $line -match $reIndex0) {
            continue
        }

        if ($insideTrack -and $line -match $reIndex1) {
            $trackBuffer.Add("    INDEX 01 00:00:00") | Out-Null
            if ($null -ne $currentFile) {
                $currentFile.Tracks.Add($trackBuffer) | Out-Null
            }
            $trackBuffer = $null
            $insideTrack = $false
            continue
        }
    }

    # If file ended while inside a track, finalize it
    if ($insideTrack -and $trackBuffer) {
        if (-not ($trackBuffer -join "`n" -match $reIndex1)) {
            $trackBuffer.Add("    INDEX 01 00:00:00") | Out-Null
        }
        if ($null -ne $currentFile) { $currentFile.Tracks.Add($trackBuffer) | Out-Null }
    }

    $fixedLines = [System.Collections.ArrayList]::new()
    foreach ($h in $header) { $fixedLines.Add($h) | Out-Null }
    foreach ($fb in $fileBlocks) {
        $fixedLines.Add($fb.FileLine) | Out-Null
        foreach ($trk in $fb.Tracks) {
            foreach ($ln in $trk) {
                $fixedLines.Add($ln) | Out-Null
            }
        }
    }

    $originalText = $lines -join "`r`n"
    $fixedText = $fixedLines -join "`r`n"

    if ($originalText -ne $fixedText) {
        if ($WriteChanges) {
            Copy-Item -LiteralPath $CueFilePath -Destination "$CueFilePath.bak" -Force
            Set-Content -LiteralPath $CueFilePath -Value $fixedText -Encoding UTF8 -Force
        }
        return @{ Changed = $true; FixedText = $fixedText }
    }
    else {
        return @{ Changed = $false; FixedText = $originalText }
    }
}
