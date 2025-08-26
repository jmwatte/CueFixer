<#
.SYNOPSIS
Export candidate audio-file matches and similarity metrics for Unfixable cue files.

.DESCRIPTION
Reads a CLIXML audit file produced by CueFixer (or a folder of cue files if you prefer), finds audio files in the cue folder, and computes similarity metrics (token Jaccard and Levenshtein when available) between cue labels/titles and candidate file basenames. Outputs a CSV suitable for offline analysis (Excel/Pandas/R).

.PARAMETER InputClixml
Path to CLIXML audit produced by CueFixer (Export-Clixml). If omitted, script will try to locate a demo file in %TEMP%.

.PARAMETER OutCsv
Where to write the CSV output. Defaults to %TEMP%\cuefixer-unfixable-candidates.csv

.PARAMETER TopN
How many top candidates to keep per cue-left-item (default 10).

.EXAMPLE
.
& .\tools\export-unfixables-candidates.ps1 -InputClixml C:\Temp\cue-audit-d-drive.clixml -OutCsv C:\Temp\candidates.csv -TopN 20
#>

param(
    [string]$InputClixml = (Join-Path $env:TEMP 'cuefixer-demo-unfixables.clixml'),
    [string]$OutCsv = (Join-Path $env:TEMP 'cuefixer-unfixable-candidates.csv'),
    [int]$TopN = 10
)

# Try to import the module so Token-Similarity / Get-LevenshteinDistance are available
$modulePath = Join-Path (Resolve-Path .. -Relative).Path 'CueFixer.psm1' 2>$null
if (Test-Path $modulePath) {
    try { Import-Module $modulePath -Force -ErrorAction Stop } catch { Write-Verbose "Could not import module: $($_.Exception.Message)" }
}

if (-not (Test-Path -LiteralPath $InputClixml)) {
    Write-Error "Input CLIXML not found: $InputClixml"
    exit 2
}

$results = Import-Clixml -Path $InputClixml -ErrorAction Stop
$unfixables = $results | Where-Object { $_.Status -ieq 'Unfixable' }
if (-not $unfixables -or $unfixables.Count -eq 0) { Write-Host "No Unfixable items found in $InputClixml"; exit 0 }

$rows = @()

foreach ($u in $unfixables) {
    $cuePath = $u.Path
    if (-not (Test-Path -LiteralPath $cuePath)) {
        Write-Warning "Cue file not found on disk: $cuePath"; continue
    }

    # Read cue and extract candidate left-hand labels: FILE entries and TITLE lines
    $cueLines = Get-Content -LiteralPath $cuePath -ErrorAction SilentlyContinue
    $fileRegex = [regex]'(?i)^\s*FILE\s+"?([^"]+)"?'
    $titleRegex = [regex]'(?i)^\s*TITLE\s+"?(.+?)"?\s*$'

    $leftItems = [System.Collections.ArrayList]::new()
    $currentFile = $null
    for ($i=0; $i -lt $cueLines.Count; $i++) {
        $lf = [string]$cueLines[$i]
        $m = $fileRegex.Match($lf)
        if ($m.Success) { $currentFile = $m.Groups[1].Value; $leftItems.Add([PSCustomObject]@{ Key=$currentFile; Type='FileRef'; Line=$i+1 }) | Out-Null; continue }
        $t = $titleRegex.Match($lf)
        if ($t.Success) { $leftItems.Add([PSCustomObject]@{ Key=$t.Groups[1].Value; Type='Title'; Line=$i+1 }) | Out-Null; continue }
    }

    # Gather audio candidates in folder
    $folder = Split-Path -Path $cuePath -Parent
    $audioFiles = Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^(?i)\.(wav|flac|mp3|aac|m4a|aif|aiff|ogg|ape)$' }

    # For each leftItem, compute scores against each candidate
    foreach ($li in $leftItems) {
        $leftLabel = $li.Key
        $normLeft = ($leftLabel -replace '^\s*\d+\s+', '') -replace '[\.\-_,]+',' ' -replace '\s+',' '
        $normLeft = $normLeft.ToLower().Trim()

        foreach ($cand in $audioFiles) {
            $candBase = [System.IO.Path]::GetFileNameWithoutExtension($cand.Name)
            $normCand = ($candBase -replace '^\s*\d+\s+', '') -replace '[\.\-_,]+',' ' -replace '\s+',' '
            $normCand = $normCand.ToLower().Trim()

            $tok = 0.0
            try { $tok = Token-Similarity -a $normLeft -b $normCand } catch { $tok = 0.0 }

            $lev = 0.0
            if (Get-Command -Name Get-LevenshteinDistance -ErrorAction SilentlyContinue) {
                try {
                    $dist = Get-LevenshteinDistance -s $normLeft -t $normCand
                    $max = [Math]::Max($normLeft.Length, $normCand.Length)
                    if ($max -gt 0) { $lev = 1.0 - ($dist / $max) }
                } catch { $lev = 0.0 }
            }

            $combined = [Math]::Max($tok, $lev)

            $rows += [PSCustomObject]@{
                CuePath = $cuePath
                LeftType = $li.Type
                LeftLabel = $leftLabel
                LeftNorm = $normLeft
                Candidate = $cand.Name
                CandidateBase = $candBase
                CandidateNorm = $normCand
                TokenSim = [math]::Round($tok,4)
                LevSim = [math]::Round($lev,4)
                Combined = [math]::Round($combined,4)
                CandidateExt = $cand.Extension
                CandidateSize = $cand.Length
                CandidateMTime = $cand.LastWriteTimeUtc
                Folder = $folder
            }
        }
    }
}

# Keep top N per CuePath+LeftLabel
$grouped = $rows | Group-Object -Property CuePath,LeftLabel
$outRows = @()
foreach ($g in $grouped) {
    $sorted = $g.Group | Sort-Object -Property Combined -Descending
    $outRows += $sorted | Select-Object -First $TopN
}

# Export
$outRows | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
Write-Host "Wrote candidate CSV to: $OutCsv"

# Helpful tip
Write-Host "Tip: open the CSV in Excel or pandas and inspect rows with Combined >= 0.75 to find likely matches. Consider lowering threshold for titles-heavy matching."
