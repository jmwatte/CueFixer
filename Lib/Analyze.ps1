<#
.SYNOPSIS
Perform a detailed audit of a single .cue file and produce structured analysis.

.DESCRIPTION
`Get-CueAuditCore` inspects a single .cue file for structural and content
issues. It returns a PSCustomObject containing Status (Clean, Fixable, Unfixable),
proposed Fixes, UpdatedLines for the proposed content, StructureErrors and a
boolean indicating whether a structural fix is needed. This is a pure
analysis function intended to be called by `Get-CueAudit` and tests.

.PARAMETER CueFilePath
Path to the .cue file to analyze.

.OUTPUTS
PSCustomObject with keys: Path, Status, Fixes, UpdatedLines, StructureErrors, NeedsStructureFix

.EXAMPLE
Get-CueAuditCore -CueFilePath 'C:\Music\Album\album.cue'
#>
function Get-CueAuditCoreImpl {
    param ([string]$CueFilePath)

    # Keep behavior compatible with original script but live in Lib/ for testability
    $cueFolder = Split-Path $CueFilePath
    $cueLines = Get-Content -LiteralPath $CueFilePath
    $updatedLines = @()
    $changesMade = $false
    $fixes = @()
    $unfixable = $false

    # Structural check
    $structureErrors = @()
    $needsStructureFix = $false
    $hadFile = $false
    $inTrack = $false
    for ($i = 0; $i -lt $cueLines.Count; $i++) {
        $line = $cueLines[$i].Trim()
        if ($line -match '^[\s]*FILE\s+"(.+?)"\s+\w+\s*$') {
            $hadFile = $true
            $inTrack = $false
            continue
        }
        if ($line -match '^[\s]*TRACK\s+\d+\s+\w+') {
            if (-not $hadFile) {
                $structureErrors += "TRACK found before any FILE (line $($i+1)): $line"
                $needsStructureFix = $true
            }
            $inTrack = $true
            continue
        }
        if ($line -match '^[\s]*INDEX\s+\d+\s+') {
            if (-not $inTrack) {
                $structureErrors += "INDEX found outside of TRACK (line $($i+1)): $line"
                $needsStructureFix = $true
            }
            continue
        }
        if ($line -match '^[\s]*PREGAP\b' -and -not $inTrack) {
            $structureErrors += "PREGAP found outside of TRACK (line $($i+1)): $line"
            $needsStructureFix = $true
        }
    }

    foreach ($line in $cueLines) {
        if ($line -match 'FILE\s+"(.+?)"\s+(WAVE|MP3|FLAC)') {
            $filename = $matches[1]
            $type = $matches[2]
            $extInCue = [System.IO.Path]::GetExtension($filename)
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filename)

            if (-not $extInCue) {
                $matchingFile = Get-ChildItem -LiteralPath $cueFolder -File | Where-Object {
                    $_.BaseName -ieq $baseName -and ($validAudioExts -contains $_.Extension.ToLower())
                } | Select-Object -First 1

                if ($matchingFile) {
                    $structureErrors += "FILE entry missing extension but matching file found (line $($cueLines.IndexOf($line)+1)): $line"
                    $needsStructureFix = $true
                    $correctedLine = "FILE `"$($matchingFile.Name)`" $type"
                    $fixes += [PSCustomObject]@{ Old = $line; New = $correctedLine }
                    $updatedLines += $correctedLine
                    $changesMade = $true
                    continue
                }
                else {
                    $structureErrors += "FILE entry missing extension and no matching file found (line $($cueLines.IndexOf($line)+1)): $line"
                    $unfixable = $true
                }
            }

            $actualFile = Get-ChildItem -LiteralPath $cueFolder -File | Where-Object {
                ($_.Name -ieq $filename -or $_.BaseName -ieq $baseName) -and ($validAudioExts -contains $_.Extension.ToLower())
            } | Select-Object -First 1

            if ($actualFile) {
                if ($validAudioExts -contains $actualFile.Extension.ToLower()) {
                    $correctedLine = "FILE `"$($actualFile.Name)`" $type"
                    $normalizedOld = ($line.Trim().ToLower() -replace '\\s+', ' ')
                    $normalizedNew = ($correctedLine.Trim().ToLower() -replace '\\s+', ' ')
                    if ($normalizedOld -ne $normalizedNew) {
                        $fixes += [PSCustomObject]@{ Old = $line; New = $correctedLine }
                        $updatedLines += $correctedLine
                        $changesMade = $true
                        continue
                    }
                }
                else {
                    $fallbackFile = Get-ChildItem -LiteralPath $cueFolder -File | Where-Object {
                        $_.BaseName -ieq $baseName -and ($validAudioExts -contains $_.Extension.ToLower())
                    } | Select-Object -First 1

                    if ($fallbackFile) {
                        $correctedLine = "FILE `"$($fallbackFile.Name)`" $type"
                        $fixes += [PSCustomObject]@{ Old = $line; New = $correctedLine }
                        $updatedLines += $correctedLine
                        $changesMade = $true
                        continue
                    }
                    else {
                        $unfixable = $true
                    }
                }
            }
            else {
                $unfixable = $true
            }
        }

        $updatedLines += $line
    }

    $status = if ($unfixable) { 'Unfixable' } elseif ($changesMade -or $needsStructureFix) { 'Fixable' } else { 'Clean' }

    return [PSCustomObject]@{
        Path              = $CueFilePath
        Status            = $status
        Fixes             = $fixes
        UpdatedLines      = $updatedLines
        StructureErrors   = $structureErrors
        NeedsStructureFix = $needsStructureFix
    }
}

# Provide a stable exported wrapper name that calls the implementation.
function Get-CueAuditCore {
    param ([string]$CueFilePath)
    Get-CueAuditCoreImpl -CueFilePath $CueFilePath
}





