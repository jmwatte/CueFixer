<#
.SYNOPSIS
Normalize structural elements of a .cue file (FILE/TRACK/INDEX) and return fixed text.

.DESCRIPTION
`Set-CueFileStructure` reads a .cue file and ensures tracks are properly nested
under FILE blocks and that missing `INDEX 01` entries are inserted where
appropriate. It returns a hashtable with `Changed` and `FixedText`. When the
`-WriteChanges` switch is supplied it will write the fixed content back to the
original file and create a `.bak` backup.

.PARAMETER CueFilePath
Path to the .cue file to process.

.PARAMETER WriteChanges
If specified, write the fixed content back to disk and create a `.bak` file.

.EXAMPLE
Set-CueFileStructure -CueFilePath 'C:\Music\Album\album.cue'
#>
function Set-CueFileStructureImpl {
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$CueFilePath,

        [switch]$WriteChanges
    )

    $lines = Get-Content -LiteralPath $CueFilePath
    $reFile    = '^\s*FILE\s+"(.+?)"\s+\w+'
    $reTrack   = '^\s*TRACK\s+([0-9]+)\s+\w+'
    $reIndex0  = '^\s*INDEX\s+00\s+'
    $reIndex1  = '^\s*INDEX\s+01\s+'
    $reMeta    = '^\s*(TITLE|PERFORMER|FLAGS|PREGAP)\b'
    $reHeader  = '^\s*(REM|GENRE|DATE|DISCID|COMMENT|TITLE|PERFORMER)\b'

    $header     = [System.Collections.ArrayList]::new()
    $fileBlocks = [System.Collections.ArrayList]::new()
    $currentFile = $null
    $trackBuffer = $null
    $insideTrack = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ($trimmed -match $reHeader -and -not $insideTrack -and -not $currentFile) {
            $header.Add($trimmed) | Out-Null
            continue
        }

        if ($trimmed -match $reTrack) {
            # Finalize previous track
            if ($trackBuffer) {
                $hasIndex01 = $false
                foreach ($entry in $trackBuffer) {
                    if ($entry -match $reIndex1) {
                        $hasIndex01 = $true
                        break
                    }
                }
                if (-not $hasIndex01) {
                    $trackBuffer.Add("    INDEX 01 00:00:00") | Out-Null
                }
                $currentFile.Tracks.Add($trackBuffer) | Out-Null
            }

            $trackBuffer = [System.Collections.ArrayList]::new()
            $trackBuffer.Add($trimmed) | Out-Null
            $insideTrack = $true
            continue
        }

        if ($trimmed -match $reFile) {
            # Finalize previous track if still open
            if ($insideTrack -and $trackBuffer) {
                $hasIndex01 = $false
                foreach ($entry in $trackBuffer) {
                    if ($entry -match $reIndex1) {
                        $hasIndex01 = $true
                        break
                    }
                }
                if (-not $hasIndex01) {
                    $trackBuffer.Add("    INDEX 01 00:00:00") | Out-Null
                }
                $currentFile.Tracks.Add($trackBuffer) | Out-Null
                $trackBuffer = $null
                $insideTrack = $false
            }

            $currentFile = [PSCustomObject]@{
                FileLine = $trimmed
                Tracks   = [System.Collections.ArrayList]::new()
            }
            $fileBlocks.Add($currentFile) | Out-Null
            continue
        }

        if ($insideTrack -and ($trimmed -match $reMeta -or $trimmed -match $reIndex1)) {
            $trackBuffer.Add($trimmed) | Out-Null
            continue
        }

        if ($insideTrack -and $trimmed -match $reIndex0) {
            continue
        }
    }

    # Finalize last track
    if ($insideTrack -and $trackBuffer) {
        $hasIndex01 = $false
        foreach ($entry in $trackBuffer) {
            if ($entry -match $reIndex1) {
                $hasIndex01 = $true
                break
            }
        }
        if (-not $hasIndex01) {
            $trackBuffer.Add("    INDEX 01 00:00:00") | Out-Null
        }
        $currentFile.Tracks.Add($trackBuffer) | Out-Null
    }

    # Reconstruct fixed cue file
    $fixedLines = [System.Collections.ArrayList]::new()
    $header | ForEach-Object { $fixedLines.Add($_) | Out-Null }

    foreach ($fb in $fileBlocks) {
        $fixedLines.Add($fb.FileLine) | Out-Null
        foreach ($trk in $fb.Tracks) {
            foreach ($ln in $trk) {
                $fixedLines.Add($ln) | Out-Null
            }
        }
    }

    $originalText = $lines -join "`r`n"
    $fixedText    = $fixedLines -join "`r`n"

    if ($originalText -ne $fixedText) {
        if ($WriteChanges) {
            Copy-Item -LiteralPath $CueFilePath -Destination "$CueFilePath.bak" -Force
            Set-Content -LiteralPath $CueFilePath -Value $fixedText -Encoding UTF8 -Force
        }
        return [PSCustomObject]@{ Changed = $true; FixedText = $fixedText }
    } else {
        return [PSCustomObject]@{ Changed = $false; FixedText = $originalText }
    }
}

# Small wrapper for test runspaces that may dot-source this file directly.
function Set-CueFileStructure {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)] [string]$CueFilePath,
        [switch]$WriteChanges
    )
    Set-CueFileStructureImpl -CueFilePath $CueFilePath -WriteChanges:$WriteChanges
}







