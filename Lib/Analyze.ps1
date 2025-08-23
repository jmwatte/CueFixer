
# Helper: normalize a filename for comparison (strip punctuation, collapse whitespace)
function Normalize-NameForCompare {
    param([string]$s)
    if (-not $s) { return '' }
    $out = $s.ToLower().Trim()
    # replace common punctuation with spaces, collapse whitespace
    $out = $out -replace '[\.\-_,]+', ' '
    $out = $out -replace '\s+', ' '
    return $out
}

# Token-based Jaccard similarity — robust to reordering of tokens (e.g. "the duck" vs "duck the")
function Token-Similarity {
    param([string]$a, [string]$b)

    if (-not $a -and -not $b) { return 1.0 }
    if (-not $a -or -not $b) { return 0.0 }

    # remove leading numeric track numbers like "07" which are noisy
    $cleanA = ($a -replace '^\s*\d+\s+', '')
    $cleanB = ($b -replace '^\s*\d+\s+', '')

    $tokensA = ($cleanA -split '\s+') | Where-Object { $_ -ne '' } | ForEach-Object { $_.ToLower() } | Select-Object -Unique
    $tokensB = ($cleanB -split '\s+') | Where-Object { $_ -ne '' } | ForEach-Object { $_.ToLower() } | Select-Object -Unique

    $inter = ($tokensA | Where-Object { $tokensB -contains $_ }).Count
    $union = ($tokensA + $tokensB | Select-Object -Unique).Count
    if ($union -eq 0) { return 0.0 }
    return [double]$inter / $union
}





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
# Ensure we have a validAudioExts array available in this function.
# Prefer the module-configured $script:validAudioExts (set by Lib/ModuleConfig.ps1),
# then any script/global validAudioExts variable, then fall back to a sensible default.
if (-not $validAudioExts -or $validAudioExts.Count -eq 0) {
    if ($script:validAudioExts -and ($script:validAudioExts.Count -gt 0)) {
        $validAudioExts = $script:validAudioExts
    }
    elseif ((Get-Variable -Name 'validAudioExts' -Scope Script -ErrorAction SilentlyContinue) -and (Get-Variable -Name 'validAudioExts' -Scope Script -ErrorAction SilentlyContinue).Value) {
        $validAudioExts = (Get-Variable -Name 'validAudioExts' -Scope Script -ErrorAction SilentlyContinue).Value
    }
    elseif ((Get-Variable -Name 'validAudioExts' -Scope Global -ErrorAction SilentlyContinue) -and (Get-Variable -Name 'validAudioExts' -Scope Global -ErrorAction SilentlyContinue).Value) {
        $validAudioExts = (Get-Variable -Name 'validAudioExts' -Scope Global -ErrorAction SilentlyContinue).Value
    }
    else {
        # Default audio extensions (lowercase, include leading dot)
        $validAudioExts = @('.flac', '.mp3', '.wav', '.aac', '.ogg', '.m4a', '.aiff', '.ape')
    }
}
    # Keep behavior compatible with original script but live in Lib/ for testability
    $cueFolder = Split-Path $CueFilePath
    # Cache folder listing once for performance and consistent lookups
    $cueFolderFiles = Get-ChildItem -LiteralPath $cueFolder -File -ErrorAction SilentlyContinue

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

            # Try exact/basename match first (use cached listing)
            $actualFile = $cueFolderFiles | Where-Object {
                ($_.Name -ieq $filename -or $_.BaseName -ieq $baseName) -and ($validAudioExts -contains $_.Extension.ToLower())
            } | Select-Object -First 1

            if ($actualFile) {
                if ($validAudioExts -contains $actualFile.Extension.ToLower()) {
                    $correctedLine = "FILE `"$($actualFile.Name)`" $type"
                    $normalizedOld = ($line.Trim().ToLower() -replace '\s+', ' ')
                    $normalizedNew = ($correctedLine.Trim().ToLower() -replace '\s+', ' ')
                    if ($normalizedOld -ne $normalizedNew) {
                        $fixes += [PSCustomObject]@{ Old = $line; New = $correctedLine }
                        $updatedLines += $correctedLine
                        $changesMade = $true
                        continue
                    }
                }
                else {
                    # existing fallback logic preserved
                    $fallbackFile = $cueFolderFiles | Where-Object {
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
               
                # No exact match — attempt fuzzy matching (token-Jaccard + optional Levenshtein)
                try {
                    # Lazy-load heuristics file if Levenshtein isn't already available
                    if (-not (Get-Command -Name Get-LevenshteinDistance -CommandType Function -ErrorAction SilentlyContinue)) {
                        $heurPath = Join-Path $PSScriptRoot 'Heuristics\FuzzyNameMatch.ps1'
                        if (Test-Path $heurPath) { . $heurPath }   # dot-source into this runspace
                    }
                } catch {
                    Write-Verbose "Could not load fuzzy heuristics: $($_.Exception.Message)"
                }
                
                $bestCandidate = $null
                $bestScore = 0.0
                
                # Use cached $cueFolderFiles (set near top of function)
                $tokenToCompare = Normalize-NameForCompare -s $baseName
                
                foreach ($candidate in $cueFolderFiles) {
                    # defensive extension handling (Extension may be $null)
                    $candExt = ([string]$candidate.Extension).ToLower().Trim()
                    if (-not ($validAudioExts -contains $candExt)) { continue }
                
                    $candidateBase = [System.IO.Path]::GetFileNameWithoutExtension($candidate.Name)
                    $candidateToken = Normalize-NameForCompare -s $candidateBase
                
                    # token-based Jaccard similarity (robust to token re-ordering)
                    $tokenSim = Token-Similarity -a $tokenToCompare -b $candidateToken
                
                    # normalized Levenshtein similarity (0..1) if available
                    $levSim = 0.0
                    if (Get-Command -Name Get-LevenshteinDistance -CommandType Function -ErrorAction SilentlyContinue) {
                        try {
                            $dist = Get-LevenshteinDistance -s $tokenToCompare -t $candidateToken
                            $maxLen = [Math]::Max(($tokenToCompare).Length, ($candidateToken).Length)
                            if ($maxLen -gt 0) { $levSim = 1.0 - ($dist / $maxLen) }
                        } catch {
                            Write-Verbose "Levenshtein failed for tokens: $($_.Exception.Message)"
                        }
                    }
                
                    # Combine measures: take the maximum so reorder-insensitive matches can win
                    $norm = [Math]::Max($tokenSim, $levSim)
                
                    if ($norm -gt $bestScore) {
                        $bestScore = $norm
                        $bestCandidate = $candidate
                    }
                }
                
                # Conservative threshold (same as heuristics tests)
                if ($bestCandidate -and ($bestScore -ge 0.75)) {
                    $correctedLine = "FILE `"$($bestCandidate.Name)`" $type"
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









