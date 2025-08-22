function Invoke-Heuristic-ExactNameMatch {
    param(
        [Parameter(Mandatory=$true)] [string]$CueFilePath,
        [Parameter(Mandatory=$true)] [string[]]$CueLines,
        [Parameter(Mandatory=$true)] [System.IO.FileInfo[]]$CueFolderFiles,
        [Parameter(Mandatory=$false)] [hashtable]$Context
    )

    $candidates = @()
    $reFile = '^[\s]*FILE\s+"(.+?)"\s+\w+'

    # avoid unused parameter analyzer warning
    $null = $Context
    # reference CueFilePath to silence analyzer
    $null = $CueFilePath

    foreach ($line in $CueLines) {
        if ($line -match $reFile) {
            $filename = $matches[1]
            # Exact match by filename (case-insensitive)
            $match = $CueFolderFiles | Where-Object { $_.Name -ieq $filename } | Select-Object -First 1
            if ($match) {
                $newLine = ($line.Trim() -replace [regex]::Escape($filename), [System.IO.Path]::GetFileName($match.Name))
                $candidates += [PSCustomObject]@{
                    Type = 'Fix'
                    OldLine = $line
                    NewLine = $newLine
                    Confidence = 1.0
                    Heuristic = 'ExactNameMatch'
                    Reason = "File found by exact filename: $($match.Name)"
                }
            }
        }
    }

    return $candidates
}






