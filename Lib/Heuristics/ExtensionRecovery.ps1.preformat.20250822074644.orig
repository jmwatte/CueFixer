function Invoke-Heuristic-ExtensionRecovery {
    param(
        [Parameter(Mandatory=$true)] [string]$CueFilePath,
        [Parameter(Mandatory=$true)] [string[]]$CueLines,
        [Parameter(Mandatory=$true)] [System.IO.FileInfo[]]$CueFolderFiles,
        [Parameter(Mandatory=$false)] [hashtable]$Context
    )

    $candidates = @()
        # reference Context to avoid unused-parameter warnings
        $null = $Context
        # reference CueFilePath to avoid unused-parameter warning (heuristics don't need full path)
        $null = $CueFilePath
        $validExts = if ($Context -and $Context.validAudioExts) { $Context.validAudioExts } else { @('.mp3','.flac','.wav','.ape') }
    $reFile = '^[\s]*FILE\s+"(.+?)"\s+\w+'

    foreach ($line in $CueLines) {
        if ($line -match $reFile) {
            $filename = $matches[1]
            $ext = [System.IO.Path]::GetExtension($filename)
            if (-not $ext) {
                $base = [System.IO.Path]::GetFileNameWithoutExtension($filename)
                $cands = $CueFolderFiles | Where-Object { $_.BaseName -ieq $base -and ($validExts -contains $_.Extension.ToLower()) }
                if ($cands.Count -eq 1) {
                    $match = $cands[0]
                    $newLine = ($line.Trim() -replace [regex]::Escape($filename), [System.IO.Path]::GetFileName($match.Name))
                    $candidates += [PSCustomObject]@{
                        Type = 'Fix'
                        OldLine = $line
                        NewLine = $newLine
                        Confidence = 0.95
                        Heuristic = 'ExtensionRecovery'
                        Reason = "Recovered extension from file: $($match.Name)"
                    }
                }
                elseif ($cands.Count -gt 1) {
                    # ambiguous
                    $candidates += [PSCustomObject]@{
                        Type = 'Ambiguous'
                        OldLine = $line
                        NewLine = $null
                        Confidence = 0.3
                        Heuristic = 'ExtensionRecovery'
                        Reason = "Multiple candidates found for base '$base'"
                    }
                }
            }
        }
    }

    return $candidates
}







