function Show-CueAudioSideBySide {
    param(
        [Parameter(Mandatory = $true)] [string]$CueFilePath,
        [Parameter(Mandatory = $true)] [string]$FolderPath,
        [Parameter(Mandatory = $false)] [switch]$FullCueLeft
    )

    try {
        $cueLines = Get-Content -LiteralPath $CueFilePath -ErrorAction Stop
    }
    catch {
        Write-Verbose "Show-CueAudioSideBySide: cannot read $CueFilePath : $($_)"
        return
    }

    # Print folder header for context
    try {
        $folderPath = Split-Path -Path $CueFilePath -Parent
        Write-Host "`n📁 Folder: $folderPath" -ForegroundColor Cyan
    }
    catch {
        # ignore
    }
    function Clear-KeyboardBuffer {
        while ([System.Console]::KeyAvailable) {
            [System.Console]::ReadKey($true) | Out-Null
        }
    }
    # Extract referenced filenames from 'FILE "name.ext"' entries and collect track titles
    $fileRegex = [regex]'(?i)^\s*FILE\s+"?([^\"]+)"?'
    $titleRegex = [regex]'(?i)^\s*TITLE\s+"?(.+?)"?\s*$'
    $trackRegex = [regex]'(?i)^\s*TRACK\s+(\d+)\s+'

    $referenced = @()
    $titles = @()
    # map of filename -> track count
    $trackCounts = @{}

    $currentFile = $null
    for ($i = 0; $i -lt $cueLines.Count; $i++) {
        $lf = [string]$cueLines[$i]
        $m = $fileRegex.Match($lf)
        if ($m.Success) {
            $currentFile = $m.Groups[1].Value
            if (-not $trackCounts.ContainsKey($currentFile)) { $trackCounts[$currentFile] = 0 }
            $referenced += $currentFile
            continue
        }
        $t = $titleRegex.Match($lf)
        if ($t.Success) { $titles += $t.Groups[1].Value; continue }

        $tr = $trackRegex.Match($lf)
        if ($tr.Success -and $currentFile) {
            # increment track count for the current FILE block
            $trackCounts[$currentFile] = $trackCounts[$currentFile] + 1
            continue
        }
    }

    $referenced = $referenced | ForEach-Object { [string]$_ } | Select-Object -Unique
    $titles = $titles | ForEach-Object { [string]$_ } | Select-Object -Unique

    # Find audio files in the folder (common extensions)
    try {
        $audioFiles = Get-ChildItem -LiteralPath $FolderPath -File -ErrorAction Stop |
        Where-Object { $_.Extension -match '^(?i)\.(wav|flac|mp3|aac|m4a|aif|aiff|ogg|ape)$' } |
        Select-Object -Property Name, BaseName
    }
    catch {
        $audioFiles = @()
    }

    # Determine fuzzy threshold (configurable via env var CUEFIXER_FUZZY_THRESHOLD)
    $defaultThreshold = 0.75
    $envThr = $null
    try { $envThr = [double]::Parse($env:CUEFIXER_FUZZY_THRESHOLD) } catch { $envThr = $null }
    $fuzzyThreshold = if ($envThr -and $envThr -gt 0 -and $envThr -le 1) { $envThr } else { $defaultThreshold }

    # Prepare rows by matching referenced entries/titles to audio files
    $sep = '  │  '
    # determine left column width dynamically based on terminal width
    try { $termWidth = $Host.UI.RawUI.WindowSize.Width } catch { $termWidth = 120 }
    $leftWidth = [Math]::Min(60, [Math]::Max(30, [int]($termWidth / 2) - 6))

    Write-Host "`nCue vs Audio files (left = cue references / titles, right = files found in folder):" -ForegroundColor Yellow
    if (($referenced.Count + $titles.Count) -eq 0) { Write-Host "  (No FILE or TITLE entries found in cue)" -ForegroundColor DarkYellow }

    # Build candidate left items: prefer FILE references, but include titles as fallback
    $leftItems = @()
    foreach ($f in $referenced) { $leftItems += [PSCustomObject]@{ Key = $f; Label = $f; Type = 'FileRef' } }
    foreach ($t in $titles) { $leftItems += [PSCustomObject]@{ Key = $t; Label = $t; Type = 'Title' } }

    # Convert audioFiles to objects we can manipulate
    $audioObjs = @()
    foreach ($a in $audioFiles) { $audioObjs += [PSCustomObject]@{ Name = $a.Name; Base = $a.BaseName; Matched = $false } }

    $rows = New-Object System.Collections.ArrayList

    # Matching function using exact/base/fuzzy title similarity
    foreach ($li in $leftItems) {
        $best = $null; $bestScore = 0.0

        # first try exact name match against full filename
        foreach ($a in $audioObjs) {
            if ($a.Name -ieq $li.Label) { $best = $a; $bestScore = 1.0; break }
        }

        if (-not $best) {
            # try base name exact
            foreach ($a in $audioObjs) {
                if ($a.Base -ieq $li.Label) { $best = $a; $bestScore = 1.0; break }
            }
        }

        if (-not $best -and $li.Type -eq 'Title') {
            # fuzzy match title -> candidate base names using Token-Similarity and optional Levenshtein
            try {
                # lazy-load heuristics file if Levenshtein isn't already available
                if (-not (Get-Command -Name Get-LevenshteinDistance -CommandType Function -ErrorAction SilentlyContinue)) {
                    $heurPath = Join-Path $PSScriptRoot 'Heuristics\FuzzyNameMatch.ps1'
                    if (Test-Path $heurPath) { . $heurPath }
                }
            }
            catch {
                Write-Verbose "Could not load fuzzy heuristics: $($_.Exception.Message)"
            }

            foreach ($a in $audioObjs) {
                $tokScore = 0.0
                try { $tokScore = (Token-Similarity -a $li.Label -b $a.Base) } catch { $tokScore = 0.0 }

                $levScore = 0.0
                if (Get-Command -Name Get-LevenshteinDistance -CommandType Function -ErrorAction SilentlyContinue) {
                    try {
                        # Normalize by removing leading numeric tokens and punctuation similar to analyzer
                        $normA = ($li.Label -replace '^\s*\d+\s+', '') -replace '[\.\-_,]+', ' '
                        $normA = ($normA -replace '\s+', ' ').ToLower().Trim()
                        $candidateBase = $a.Base -replace '^\s*\d+\s+', ''
                        $normB = ($candidateBase -replace '[\.\-_,]+', ' ') -replace '\s+', ' '
                        $normB = $normB.ToLower().Trim()
                        $dist = Get-LevenshteinDistance -s $normA -t $normB
                        $maxLen = [Math]::Max($normA.Length, $normB.Length)
                        if ($maxLen -gt 0) { $levScore = 1.0 - ($dist / $maxLen) }
                    }
                    catch {
                        Write-Verbose "Levenshtein failed for '$($li.Label)' vs '$($a.Base)': $($_.Exception.Message)"
                        $levScore = 0.0
                    }
                }

                $combined = [Math]::Max($tokScore, $levScore)
                if ($combined -gt $bestScore) { $bestScore = $combined; $best = $a }
            }

            # require a reasonable threshold to consider it a match
            if ($bestScore -lt $fuzzyThreshold) { $best = $null }
        }

        if ($best) {
            $best.Matched = $true
            # attach track count to right label if available
            $countText = ''
            if ($trackCounts.ContainsKey($best.Name)) { $countText = " ($($trackCounts[$best.Name]) track(s))" }
            $rows.Add([PSCustomObject]@{ Left = $li.Label; Right = ($best.Name + $countText); Match = $true }) | Out-Null
        }
        else {
            $rows.Add([PSCustomObject]@{ Left = $li.Label; Right = ''; Match = $false }) | Out-Null
        }
    }

    # Add any unmatched audio files as right-only rows
    foreach ($a in $audioObjs | Where-Object { -not $_.Matched }) {
        $rows.Add([PSCustomObject]@{ Left = ''; Right = $a.Name; Match = $false }) | Out-Null
    }

    # Print rows or full cue file on the left side when requested
    $useFullLeft = $FullCueLeft -or ($env:CUEFIXER_FULLCUELEFT -in @('1', 'true', 'True'))

    if ($useFullLeft) {
        # Print header and show the entire cue file lines on the left, paired with audio rows on the right where available
        Write-Host "Legend: left = cue file contents; right = files found in folder (green=match)" -ForegroundColor Yellow
        Write-Host "Fuzzy threshold = $fuzzyThreshold (set CUEFIXER_FUZZY_THRESHOLD to change)" -ForegroundColor DarkCyan

        $leftLines = $cueLines | ForEach-Object { ($_ -as [string]).Trim() }
        $maxLines = [Math]::Max($leftLines.Count, $rows.Count)

        # Build a quick mapping of matched right items to left lines by searching leftLines for the right base name
        $matchLeftIndices = @{}
        for ($ri = 0; $ri -lt $rows.Count; $ri++) {
            $r = $rows[$ri]
            if ($r.Match -and -not [string]::IsNullOrEmpty($r.Right)) {
                # Derive a robust candidate base name for searching left cue lines:
                # - remove any trailing parenthetical like " (3 track(s))"
                # - strip extension and any leading numeric track prefixes like "01 - "
                try {
                    $rawRight = ($r.Right -split '\s+\(')[0]
                    $candBase = [System.IO.Path]::GetFileNameWithoutExtension($rawRight)
                    # remove leading numeric tokens and separators (e.g. "01 - ", "1.")
                    $candBase = $candBase -replace '^\s*\d+[\s\-\._:]*', ''
                    $candidate = $candBase.Trim()
                }
                catch {
                    $candidate = ($r.Right -split '\s+')[0]
                }

                for ($li = 0; $li -lt $leftLines.Count; $li++) {
                    if ($leftLines[$li] -and $leftLines[$li].IndexOf($candidate, [System.StringComparison]::InvariantCultureIgnoreCase) -ge 0) {
                        if (-not $matchLeftIndices.ContainsKey($li)) { $matchLeftIndices[$li] = @() }
                        $matchLeftIndices[$li] += $candidate
                        break
                    }
                }
            }
        }

        for ($i = 0; $i -lt $maxLines; $i++) {
            $left = if ($i -lt $leftLines.Count) { $leftLines[$i] } else { '' }
            $right = if ($i -lt $rows.Count) { $rows[$i].Right } else { '' }

            $leftText = if ($left -and $left.Length -gt $leftWidth) { $left.Substring(0, $leftWidth - 3) + '...' } else { ($left).PadRight($leftWidth) }
            # Color left green when we have a matched right candidate referencing this left line
            $leftColor = if ($matchLeftIndices.ContainsKey($i)) { 'Green' } else { 'Gray' }
            Write-Host "  $leftText$sep" -NoNewline -ForegroundColor $leftColor
            if ($right) {
                # reuse right coloring logic
                $r = if ($i -lt $rows.Count) { $rows[$i] } else { $null }
                if ($r -and -not [string]::IsNullOrEmpty($r.Right)) { $rightColor = if ($r.Match) { 'Green' } else { 'DarkGray' } } else { $rightColor = 'Gray' }
                Write-Host "$right" -ForegroundColor $rightColor
            }
            else { Write-Host "" }
        }

        Write-Host ""
    }
    else {
        # Print rows (default behavior)
        Write-Host "Legend: " -NoNewline; Write-Host "green=match" -ForegroundColor Green -NoNewline; Write-Host ", red=missing cue ref" -ForegroundColor Red -NoNewline; Write-Host ", dark-gray=unreferenced audio file`n"
        Write-Host "Fuzzy threshold = $fuzzyThreshold (set CUEFIXER_FUZZY_THRESHOLD to change)" -ForegroundColor DarkCyan
        foreach ($r in $rows) {
            $left = $r.Left
            $right = $r.Right
            if (-not [string]::IsNullOrEmpty($left)) {
                $leftColor = if ($r.Match) { 'Green' } else { 'Red' }
            }
            else { $leftColor = 'Gray' }
            if (-not [string]::IsNullOrEmpty($right)) {
                $rightColor = if ($r.Match) { 'Green' } else { 'DarkGray' }
            }
            else { $rightColor = 'Gray' }

            $leftText = if ($left -and $left.Length -gt $leftWidth) { $left.Substring(0, $leftWidth - 3) + '...' } else { ($left).PadRight($leftWidth) }
            Write-Host "  $leftText$sep" -NoNewline -ForegroundColor $leftColor
            if ($right) { Write-Host "$right" -ForegroundColor $rightColor } else { Write-Host "" }
        }

        Write-Host ""
    }

}
function Read-OneKey {
    param([string]$Prompt)

    # Drain any queued Console keys (works in native consoles)
    function Clear-KeyboardBuffer {
        try {
            while ([System.Console]::KeyAvailable) {
                [System.Console]::ReadKey($true) | Out-Null
            }
        }
        catch {
            # ignore - some hosts don't support Console.KeyAvailable
        }
    }

    # Debug toggle: set CUEFIXER_DEBUG_RAWKEYS=1 to print low-level key info
    $debugRaw = $env:CUEFIXER_DEBUG_RAWKEYS -in @('1', 'true', 'True')

    # Try to give the host a moment to settle and drain any Console buffer
    Clear-KeyboardBuffer
    Start-Sleep -Milliseconds 120

    # Print prompt (no newline) and block for a single keypress
    Write-Host $Prompt -NoNewline

    # Prefer Host.UI.RawUI (works in VS Code integrated terminal and many PS hosts)
    try {
        $raw = $Host.UI.RawUI
        if ($raw -and $raw.GetType()) {
            while ($true) {
                $keyInfo = $raw.ReadKey('NoEcho,IncludeKeyDown')

                if ($debugRaw) {
                    $charCode = if ($keyInfo.Character) { [int][char]$keyInfo.Character } else { -1 }
                    Write-Host "`nDEBUG: CharCode=$charCode Char='$(($keyInfo.Character))' VK=$($keyInfo.VirtualKeyCode)" -ForegroundColor DarkGray
                }

                # If Character is ESC (27), attempt to read CSI/escape sequences (best-effort)
                $charCode = if ($keyInfo.Character) { [int][char]$keyInfo.Character } else { -1 }
                if ($charCode -eq 27) {
                    $seq = ''
                    for ($i = 0; $i -lt 3; $i++) {
                        try {
                            $k2 = $raw.ReadKey('NoEcho,IncludeKeyDown')
                            $seq += if ($k2.Character) { [string]$k2.Character } else { '' }
                        }
                        catch { break }
                    }
                    if ($debugRaw) { Write-Host "DEBUG: ESC seq='$seq'" -ForegroundColor DarkGray }
                    Write-Host ''
                    if ($seq.StartsWith('[')) {
                        switch ($seq.Substring(0, [Math]::Min(2, $seq.Length))) {
                            '[D' { return 'LEFT' }
                            '[C' { return 'RIGHT' }
                            '[A' { return 'UP' }
                            '[B' { return 'DOWN' }
                            default { return 'ESC' }
                        }
                    }
                    return 'ESC'
                }

                # Map VirtualKeyCode (Windows) when available
                $vk = 0
                try { $vk = [int]$keyInfo.VirtualKeyCode } catch { $vk = 0 }
                switch ($vk) {
                    37 { Write-Host ''; return 'LEFT' }   # VK_LEFT
                    39 { Write-Host ''; return 'RIGHT' }  # VK_RIGHT
                    36 { Write-Host ''; return 'HOME' }   # VK_HOME
                    35 { Write-Host ''; return 'END' }    # VK_END
                    13 { Write-Host ''; return '' }       # Enter -> Next (empty token)
                }

                # If Character is printable, return it
                if (-not [string]::IsNullOrEmpty($keyInfo.Character) -and -not [char]::IsControl($keyInfo.Character)) {
                    Write-Host ''
                    $ch = [string]$keyInfo.Character
                    switch ($ch) {
                        '<' { return 'LEFT' }
                        '>' { return 'RIGHT' }
                        default { return $ch }
                    }
                }

                # Otherwise spin and wait for next key
            }
        }
    }
    catch {
        # Fall back to System.Console (native console hosts)
    }

    # Fallback: use System.Console.ReadKey (blocking) when RawUI isn't available
    try {
        $cki = [System.Console]::ReadKey($true)
        Write-Host ''
        if ($debugRaw) { Write-Host "DEBUG: Console Key=$($cki.Key) KeyChar='$($cki.KeyChar)'" -ForegroundColor DarkGray }

        switch ($cki.Key) {
            'LeftArrow' { return 'LEFT' }
            'RightArrow' { return 'RIGHT' }
            'Home' { return 'HOME' }
            'End' { return 'END' }
            'Enter' { return '' }     # Enter => Next (empty token)
            'Escape' { return 'ESC' }
            default {
                try {
                    if (-not [string]::IsNullOrEmpty($cki.KeyChar) -and -not [char]::IsControl($cki.KeyChar)) {
                        return [string]$cki.KeyChar
                    }
                }
                catch { }
                return ''
            }
        }
    }
    catch {
        # Last resort: clear buffers and use Read-Host (blocking)
        Clear-KeyboardBuffer
        Write-Host ''
        return (Read-Host $Prompt)
    }
}
function Show-UnfixablesOverview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][System.Collections.ArrayList]$CueFiles,
        [Parameter(Mandatory = $false)][switch]$FullCueLeft
    )

    foreach ($fi in $CueFiles) {
        try {
            $cuePath = if ($fi -is [System.IO.FileInfo]) { $fi.FullName } else { $fi.FullName }
            $folder = Split-Path -Path $cuePath -Parent
            $folderParts = $folder -split "[\\/]"
            $excerpt = if ($folderParts.Length -ge 2) { "$($folderParts[-2])\$($folderParts[-1])" } elseif ($folderParts.Length -eq 1) { $folderParts[-1] } else { $folder }
            Write-Host "`nPreview: $cuePath" -ForegroundColor DarkCyan
            Write-Host "Folder: $excerpt ($folder)" -ForegroundColor DarkYellow
            if (Get-Command -Name Show-CueAudioSideBySide -ErrorAction SilentlyContinue) {
                Show-CueAudioSideBySide -CueFilePath $cuePath -FolderPath $folder -FullCueLeft:($FullCueLeft.IsPresent)
            }
            else {
                Write-Host "(Side-by-side preview not available: Show-CueAudioSideBySide not exported)" -ForegroundColor DarkYellow
            }
        }
        catch {
            Write-Warning "Preview failed for $($fi.FullName): $($_.Exception.Message)"
        }
    }
}


function Invoke-InteractivePaged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.Collections.ArrayList]$CueFiles,
        [Parameter(Mandatory = $false)]
        [switch]$FullCueLeft
    )

    if (-not $CueFiles -or $CueFiles.Count -eq 0) { return }

    $i = 0
    while ($i -lt $CueFiles.Count) {
        $item = $CueFiles[$i]
        $cuePath = if ($item -is [System.IO.FileInfo]) { $item.FullName } else { $item.FullName }
        $folderPath = Split-Path -Path $cuePath -Parent

        # Print folder header and quick file list
        if (-not ($env:CUEFIXER_NO_CLEAR -in @('1', 'true', 'True'))) { Clear-Host }
        Write-Host "`n📁 Folder: $folderPath" -ForegroundColor Cyan
        try { $filesInFolder = Get-ChildItem -LiteralPath $folderPath -Filter '*.cue' -File -ErrorAction Stop } catch { $filesInFolder = @() }
        Write-Host "Found $($filesInFolder.Count) .cue file(s):" -ForegroundColor DarkCyan
        $filesInFolder | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor DarkGray }

        # Preview
        try {
            if ($env:CUEFIXER_INTERACTIVE_PREVIEW -eq '0') { Write-Host "(Interactive preview disabled)" -ForegroundColor DarkYellow }
            else {
                # Respect explicit parameter first, otherwise fall back to env var for backward compatibility
                $useFullLeft = if ($FullCueLeft.IsPresent) { $true } else { $env:CUEFIXER_FULLCUELEFT -in @('1', 'true', 'True') }
                Show-CueAudioSideBySide -CueFilePath $cuePath -FolderPath $folderPath -FullCueLeft:($useFullLeft)
            }
        }
        catch { Write-Verbose "Preview failed: $_" }

        # Analyze and show fixable/unfixable info
        $results = @( Get-CueAuditCore -CueFilePath $cuePath )
        $res = $results[0]
        switch ($res.Status) {
            'Fixable' { Show-Fixable   -Results $results -DryRun }
            'Unfixable' { Show-Unfixable -Results $results }
            default { Write-Verbose "No fixes for $($res.Path)" }
        }

        # Prompt for action for this page
        $promptLine = "File $($i+1)/$($CueFiles.Count) - [E] Edit  [O] Open folder  [P] Play  [D] Delete  [Q] Quit  [R] Retry  (Enter = Next) "
        if ($env:CUEFIXER_TEST_CHOICE) { $choice = $env:CUEFIXER_TEST_CHOICE } else { $choice = Read-OneKey $promptLine }
        $selKey = if ($null -eq $choice) { '' } else { [string]$choice }
        $selKey = $selKey.ToUpperInvariant()

        switch ($selKey) {
            '' { $i++ ; continue }
            'ENTER' { $i++ ; continue }
            'E' {
                Open-InEditor $cuePath
                try { Read-OneKey "Press any key when finished editing to continue... " | Out-Null } catch { Read-Host "Press Enter when finished editing to continue..." | Out-Null }
                continue
            }
            'O' {
                try { Start-Process -FilePath 'explorer.exe' -ArgumentList ("`"$(Split-Path -Path $cuePath -Parent)`"") -ErrorAction Stop } catch { Write-Verbose "Failed to open folder: $_" }
                continue
            }
            'P' { Start-Process $cuePath ; continue }
            'R' { continue }
            'Q' { break }
            'D' {
                $confirm = $null
                if ($env:CUEFIXER_TEST_CONFIRM) { $confirm = $env:CUEFIXER_TEST_CONFIRM }
                if (-not $confirm) { try { $confirm = Read-OneKey "Are you sure you want to delete '$([System.IO.Path]::GetFileName($cuePath))'? [y/N] " } catch { $confirm = Read-Host "Are you sure you want to delete '$([System.IO.Path]::GetFileName($cuePath))'? [y/N] " } }
                if ($confirm -and ([string]$confirm).ToUpperInvariant() -in @('Y', 'YES')) {
                    try { $ts = Get-Date -Format 'yyyyMMddHHmmss'; $backupPath = "$cuePath.deleted.$ts.bak"; Move-Item -LiteralPath $cuePath -Destination $backupPath -ErrorAction Stop; Write-Host "Deleted (moved to): $backupPath" -ForegroundColor Yellow; $CueFiles.RemoveAt($i); continue } catch { Write-Warning "Failed to delete: $_" ; continue }
                }
                else { continue }
            }
            default { Write-Verbose "Invalid choice: $selKey" ; continue }
        }
    }
}
function Invoke-InteractiveFixImpl {
    [CmdletBinding()]
    param(
        # Accept objects from the pipeline (FileInfo or fileinfo-like PSCustomObject)
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [object]$CueFiles,

        # Backwards-compatible named parameter for callers that pass an ArrayList
        [Parameter(Mandatory = $false)]
        [System.Collections.ArrayList]$CueFilesCollection,

        [switch]$FullCueLeft
    )

    begin {
        # accumulator ArrayList used for the interactive logic
        $cueList = New-Object System.Collections.ArrayList

        # Tracing (write JSON events when CUEFIXER_TRACE=1)
        $traceEnabled = $false
        if ($env:CUEFIXER_TRACE -eq '1') {
            $traceEnabled = $true
            $logPath = Join-Path $env:TEMP 'cuefixer-interactive-log.json'
            if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
            function Write-TraceEvent { param($obj) if ($traceEnabled) { $obj | ConvertTo-Json -Depth 6 | Add-Content -LiteralPath $logPath } }
        }

        # If the caller supplied -CueFiles as a named parameter (e.g. Invoke-InteractiveFixImpl -CueFiles $alist),
        # coerce that value into the accumulator right away. This covers both single objects and enumerable collections.
        if ($PSBoundParameters.ContainsKey('CueFiles') -and $null -ne $CueFiles) {
            if ($CueFiles -is [System.Collections.IEnumerable] -and -not ($CueFiles -is [string])) {
                foreach ($item in $CueFiles) { [void]$cueList.Add($item) }
            }
            else {
                [void]$cueList.Add($CueFiles)
            }
        }
        # DO NOT return here — we must allow process{} (pipeline items) and end{} (named collection param) to run.
    }

    process {
        # Collect pipeline-bound items (invoked once per pipeline object).
        # Keep this minimal and fast so we don't run expensive logic until all pipeline input has arrived.
        if ($null -ne $CueFiles) {
            if ($CueFiles -is [System.Collections.IEnumerable] -and -not ($CueFiles -is [string])) {
                foreach ($item in $CueFiles) { [void]$cueList.Add($item) }
            }
            else {
                [void]$cueList.Add($CueFiles)
            }
        }
    }

    end {
        # Merge named collection param if provided
        if ($PSBoundParameters.ContainsKey('CueFilesCollection') -and $null -ne $CueFilesCollection) {
            if ($CueFilesCollection -is [System.Collections.IEnumerable]) {
                foreach ($it in $CueFilesCollection) { [void]$cueList.Add($it) }
            }
            else {
                [void]$cueList.Add($CueFilesCollection)
            }
        }
$uniqueCueListRaw = $cueList | Sort-Object -Unique
$finalCueList = New-Object System.Collections.ArrayList
if ($uniqueCueListRaw -is [System.Collections.IEnumerable] -and -not ($uniqueCueListRaw -is [string])) {
    foreach ($item in $uniqueCueListRaw) {
        [void]$finalCueList.Add($item)
    }
} else {
    [void]$finalCueList.Add($uniqueCueListRaw)
}
        $cueList = $finalCueList

        
        # If no items were collected, bail with a helpful message
        if (-not $cueList -or $cueList.Count -eq 0) {
            Write-Warning "No cue files provided to Invoke-InteractiveFixImpl; nothing to do."
            return
        }

        # Now proceed with the grouping and interactive loop (moved here so it runs once for the full collection)
        # Convert grouped folders into an indexable array to allow cross-folder navigation
        # Normalize input into groups of FileInfo objects grouped by folder so we can index across folders
        $first = $cueList[0]

        # If caller already passed GroupInfo-like objects (Group + Name), use them as-is
        if ($first -is [Microsoft.PowerShell.Commands.GroupInfo] -or
            ($first.PSObject.Properties['Group'] -and $first.PSObject.Properties['Name'])) {
            $folders = [System.Collections.ArrayList]$cueList
        }
        else {
            $files = New-Object System.Collections.ArrayList
            foreach ($item in $cueList) {
                if ($null -eq $item) { continue }

                if ($item -is [System.IO.FileInfo]) {
                    [void]$files.Add($item)
                    continue
                }

                # Accept objects with FullName/DirectoryName/Name or raw path strings
                try {
                    if ($item -is [string]) {
                        $fi = Get-Item -LiteralPath $item -ErrorAction Stop
                        if ($fi -is [System.IO.FileInfo]) { [void]$files.Add($fi); continue }
                    }
                    elseif ($item.PSObject.Properties['FullName']) {
                        $path = $item.FullName
                        $fi = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
                        if ($fi -is [System.IO.FileInfo]) { [void]$files.Add($fi); continue }
                        # If file doesn't exist, try to build a fileinfo-like object? We prefer real FileInfo when possible.
                    }
                }
                catch {
                    # ignore items that can't be resolved to files
                }
            }

            if ($files.Count -gt 0) {
                $folders = $files | Group-Object -Property DirectoryName | Sort-Object Name
            }
            else {
                $folders = @()
            }
        }

        if (-not $folders -or $folders.Count -eq 0) { return }

        $folderCount = $folders.Count
        # Build a flat list of files with folder/file indices so navigation is simple and reliable
        $flatFiles = New-Object System.Collections.ArrayList
        for ($fi = 0; $fi -lt $folders.Count; $fi++) {
            $grp = $folders[$fi]
            $filesInGrp = $grp.Group
            for ($fj = 0; $fj -lt $filesInGrp.Count; $fj++) {
                $obj = [PSCustomObject]@{
                    FolderIndex = $fi
                    FileIndex   = $fj
                    FolderPath  = $grp.Name
                    FileObj     = $filesInGrp[$fj]
                }
                [void]$flatFiles.Add($obj)
            }
        }

        if ($flatFiles.Count -eq 0) { return }

        # --- Begin the interactive UI (unchanged from previous logic) ---
        $totalFiles = $flatFiles.Count
        $pos = 0
        $done = $false

        # Persistent one-line help banner for keyboard shortcuts
        Write-Host "Navigation: Left/Right = Prev/Next • Home/End = First/Last • A=Apply • S/Enter=Skip • D=Delete • E=Edit • P=Play • R=Retry • Q=Quit" -ForegroundColor DarkCyan

        # If standard input is redirected (for example when run from a non-interactive host),
        # we should not silently auto-advance through files. Detect this and bail with a helpful
        # message so the caller knows to run in an interactive terminal (pwsh) or use -PreviewOnly.
        try {
            $isInputRedirected = [System.Console]::IsInputRedirected
        }
        catch {
            $isInputRedirected = $false
        }
        if ($isInputRedirected -and -not $env:CUEFIXER_TEST_CHOICE) {
            Write-Warning "Interactive input appears to be redirected or unavailable. Run this command in an interactive terminal (pwsh) or use -PreviewOnly. Aborting interactive session."
            return
        }

        # Reuse or define Read-OneKey if necessary (keeps your existing implementation)
        if (-not (Get-Command -Name Read-OneKey -ErrorAction SilentlyContinue)) {
            # (copy Read-OneKey function body from your original file here)
            # For brevity I assume Read-OneKey is defined elsewhere in the file; if not, keep your existing Read-OneKey code here.
        }

        while (-not $done) {
            if ($pos -lt 0) { $pos = 0 }
            if ($pos -ge $totalFiles) { break }

            $entry = $flatFiles[$pos]
            $folderIndex = $entry.FolderIndex
            $fileIndex = $entry.FileIndex
            $currentFile = $entry.FileObj
            $folderPath = $entry.FolderPath
            $filesInFolder = $folders[$folderIndex].Group
            $fileCount = $filesInFolder.Count

            # Respect CUEFIXER_NO_CLEAR to allow 'ever-growing' overview output when desired
            if (-not ($env:CUEFIXER_NO_CLEAR -in @('1', 'true', 'True'))) { Clear-Host }
            # Visible folder header so the user always sees which folder/album is being previewed
            Write-Host "`n📁 Folder: $folderPath" -ForegroundColor Cyan
            Write-Host "Found $($filesInFolder.Count) .cue file(s):" -ForegroundColor DarkCyan
            $filesInFolder | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor DarkGray }

            # Analyze the current file only
            $results = @( Get-CueAuditCore -CueFilePath $currentFile.FullName )
            if ($traceEnabled) { Write-TraceEvent @{ Event = 'Preview'; Folder = $folderPath; File = $currentFile.Name } }

            Write-Verbose "`n🧪 Previewing changes (DryRun) for $($currentFile.Name)..."
            # Render side-by-side cue vs audio files to help the user decide
            try {
                $useFullLeft = if ($FullCueLeft.IsPresent) { $true } else { $env:CUEFIXER_FULLCUELEFT -in @('1', 'true', 'True') }
                Show-CueAudioSideBySide -CueFilePath $currentFile.FullName -FolderPath $folderPath -FullCueLeft:($useFullLeft)
            }
            catch {
                Write-Verbose "Show-CueAudioSideBySide failed: $_"
            }

            # Show only the relevant view to reduce noise
            $res = $results[0]
            switch ($res.Status) {
                'Fixable' { Show-Fixable   -Results $results -DryRun }
                'Unfixable' { Show-Unfixable -Results $results }
                default { Write-Verbose "No fixes for $($res.Path)" }
            }

            # Visual status prompt: File X/Y in Folder N/M
            $statusLine = "File $($fileIndex + 1)/$fileCount in Folder $($folderIndex + 1)/$folderCount"

            if ($env:CUEFIXER_TEST_CHOICE) {
                $choice = $env:CUEFIXER_TEST_CHOICE
            }
            else {
                $choice = Read-OneKey "`n$statusLine -[A]pply [E]dit  [M]akeCueFile  [O]pen folder  [P]lay  [D]elete  [Q]uit  [R]etry  (Enter = Next, Left/Right = Prev/Next, Home = First, End = Last) "
            }

            if ($traceEnabled) { Write-TraceEvent @{ Event = 'Prompt'; Folder = $folderPath; File = $currentFile.Name; Choice = $choice } }

            # Normalize choice to string and uppercase to avoid System.Char issues
            $selKey = if ($null -eq $choice) { '' } else { [string]$choice }
            $selKey = $selKey.ToUpperInvariant()

            switch ($selKey) {
                '' {
                    Write-Verbose "⏭️ Next file..."
                    $pos = ($pos + 1) % $totalFiles
                    continue
                }
                'RIGHT' {
                    Write-Verbose "⏭️ Quick next (Right arrow)..."
                    $pos = ($pos + 1) % $totalFiles
                    continue
                }
                'LEFT' {
                    Write-Verbose "⏮️ Moving to previous file (Left arrow)..."
                    $pos = ($pos - 1 + $totalFiles) % $totalFiles
                    continue
                }
                'HOME' { $pos = 0; continue }
                'END' { $pos = ($totalFiles - 1); continue }
                'O' {
                    $openPath = (Split-Path -Path $currentFile.FullName -Parent)
                    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ("`"$openPath`"") -ErrorAction Stop } catch { Write-Verbose "Failed to open folder: $($_.Exception.Message)" }
                    continue
                }
                'E' {
                    Write-Verbose "📝 Opening cue file in default editor: $($currentFile.FullName)"
                    Open-InEditor $currentFile.FullName
                    try { Read-OneKey "Press any key when finished editing to continue... " | Out-Null } catch { Read-Host "Press Enter when finished editing to continue..." | Out-Null }
                    continue
                }
                'P' { Start-Process $currentFile.FullName; continue }
                'Q' { Write-Verbose "👋 Quitting interactive."; $done = $true; break }
                'R' { Write-Verbose "🔁 Re-analyzing $($currentFile.Name)..."; continue }
                'A' {
                    Write-Verbose "⚙️ Applying fixes to $($currentFile.Name)..."
                    try {
                        $fixResults = @( Invoke-CueFixCore -CueFilePath $currentFile.FullName -WhatIf:$true -ErrorAction Stop )
                        foreach ($fr in $fixResults) {
                            if ($fr.Status -eq 'Fixed') { Write-Host "✅ Fixed: $($fr.Path)" -ForegroundColor Green }
                            elseif ($fr.Status -eq 'Unfixable') { Write-Host "❌ Unfixable: $($fr.Path)" -ForegroundColor Red }
                            else { Write-Host "ℹ️  No changes needed for: $($fr.Path)" -ForegroundColor DarkCyan }
                        }
                    }
                    catch { Write-Warning "Failed to apply fixes: $($_.Exception.Message)" }
                    continue
                }
                'M' {
                    # Make minimal cuefile from current folder audio, open it for user editing,
                    # then ALWAYS finalize it into a playable cue after the editor is closed.
                    $cueFolder = $currentFile.DirectoryName
                    $proposed = Join-Path $cueFolder ($currentFile.BaseName + '.cue')

                    # Overwrite prompt if target exists
                    if (Test-Path $proposed) {
                        $ok = Read-OneKey "Output '$proposed' already exists. Overwrite? [y/N] "
                        if ($ok -notmatch '^[Yy]') { Write-Host "Skipped creating cue."; break }
                    }

                    # Ensure generator helper is available
                    if (-not (Get-Command -Name New-CueFileFromFolder -ErrorAction SilentlyContinue)) {
                        $helper = Join-Path $PSScriptRoot '..\Lib\MakeCueFromFolder.ps1'
                        if (Test-Path $helper) { . $helper } else {
                            Write-Warning "MakeCue helper not found: $helper. Cannot create cue."
                            break
                        }
                    }

                    try {
                        $gen = New-CueFileFromFolder -FolderPath $cueFolder -OutputCuePath $proposed -Overwrite:$true
                    }
                    catch {
                        Write-Warning "Failed to create minimal cue: $($_.Exception.Message)"
                        break
                    }

                    # Normalize returned path: accept string or PSCustomObject shapes
                    $generatedPath = $null
                    if ($gen -is [string]) { $generatedPath = $gen }
                    elseif ($gen -and $gen.PSObject.Properties.Name -contains 'OutPath') { $generatedPath = $gen.OutPath }
                    elseif ($gen -and $gen.PSObject.Properties.Name -contains 'CuePath') { $generatedPath = $gen.CuePath }
                    elseif ($gen -and $gen.PSObject.Properties.Name -contains 'Path') { $generatedPath = $gen.Path }
                    else { $generatedPath = $proposed }

                    if (-not $generatedPath -or -not (Test-Path $generatedPath)) {
                        Write-Warning "No cue created at expected path '$proposed'. Aborting M flow."
                        break
                    }

                    Write-Host "Created minimal cue: $generatedPath" -ForegroundColor Green

                    # Open it for editing if user wants (existing UX)
                    $open = Read-OneKey "Open the generated cue in editor now? [Y/n] "
                    if ($open -notmatch '^[Nn]') {
                        try {
                            if (Get-Command -Name Open-InEditor -ErrorAction SilentlyContinue) {
                                Open-InEditor $generatedPath
                            }
                            elseif ($env:EDITOR) {
                                Start-Process -FilePath $env:EDITOR -ArgumentList $generatedPath -ErrorAction Stop
                            }
                            elseif ($env:VISUAL) {
                                Start-Process -FilePath $env:VISUAL -ArgumentList $generatedPath -ErrorAction Stop
                            }
                            else {
                                Start-Process -FilePath 'notepad.exe' -ArgumentList $generatedPath -ErrorAction Stop
                            }
                        }
                        catch {
                            Write-Verbose "Failed to open editor: $($_.Exception.Message). Falling back to notepad."
                            try { Start-Process -FilePath 'notepad.exe' -ArgumentList $generatedPath -ErrorAction Stop } catch { Write-Warning "Unable to open an editor for '$generatedPath'." }
                        }

                        # Wait for user to finish editing (preserve current UX)
                        try { Read-OneKey "Press any key when finished editing to continue... " | Out-Null } catch { Read-Host "Press Enter when finished editing to continue..." | Out-Null }

                        # After editing, auto-finalize (no opt-out)
                        try {
                            $lines = Get-Content -LiteralPath $generatedPath -ErrorAction Stop | ForEach-Object { ($_ -as [string]).Trim() }
                        }
                        catch {
                            Write-Warning "Cannot read generated cue to finalize: $($_.Exception.Message)"
                            continue
                        }

                        $fileCount = (($lines | Where-Object { $_ -match '(?i)^\s*FILE\s+' }) | Measure-Object).Count
                        if ($fileCount -eq 0) {
                            Write-Warning "Generated/edited cue contains no 'FILE' entries; skipping automatic finalization."
                            continue
                        }

                        # Ensure finalizer helper is available
                        if (-not (Get-Command -Name Complete-CueFromEditedFile -ErrorAction SilentlyContinue)) {
                            $finalizer = Join-Path $PSScriptRoot '..\Lib\FinalizeCue.ps1'
                            if (Test-Path $finalizer) { . $finalizer } else {
                                Write-Warning "Finalizer helper not found: $finalizer. Cannot finalize cue."
                                continue
                            }
                        }

                        # Run finalizer (creates backup). No interactive opt-out; backup is automatic.
                        try {
                            $r = Complete-CueFromEditedFile -CuePath $generatedPath -Overwrite:$true
                            if ($r) {
                                Write-Host "Finalized cue: $($r.CuePath) (backup: $($r.Backup))" -ForegroundColor Green
                                # Open finalized cue for review
                                try { Invoke-Item $r.CuePath } catch { Invoke-Item $r.CuePath }
                            }
                            else {
                                Write-Warning "Finalizer ran but returned no result."
                            }
                        }
                        catch {
                            Write-Warning "Automatic finalization failed: $($_.Exception.Message)"
                        }
                    }
                    else {
                        Write-Host "Not opening generated cue." -ForegroundColor DarkCyan
                        # If user chose not to open the file, still attempt to finalize immediately
                        try {
                            $lines = Get-Content -LiteralPath $generatedPath -ErrorAction Stop | ForEach-Object { ($_ -as [string]).Trim() }
                            $fileCount = (($lines | Where-Object { $_ -match '(?i)^\s*FILE\s+' }) | Measure-Object).Count
                            if ($fileCount -gt 0) {
                                if (-not (Get-Command -Name Complete-CueFromEditedFile -ErrorAction SilentlyContinue)) {
                                    $finalizer = Join-Path $PSScriptRoot '..\Lib\FinalizeCue.ps1'
                                    if (Test-Path $finalizer) { . $finalizer } else { Write-Warning "Finalizer helper not found: $finalizer. Cannot finalize cue."; continue }
                                }
                                $r = Complete-CueFromEditedFile -CuePath $generatedPath -Overwrite:$true
                                if ($r) { Write-Host "Finalized cue: $($r.CuePath) (backup: $($r.Backup))" -ForegroundColor Green }
                            }
                            else {
                                Write-Warning "Generated cue contains no 'FILE' entries; skipping automatic finalization."
                            }
                        }
                        catch {
                            Write-Warning "Automatic finalization (no-edit path) failed: $($_.Exception.Message)"
                        }
                    }

                    continue
                }
                # --- Insert into Lib\Interactive.ps1, inside the interactive switch($selKey) where 'M' is handled ---
                'C' {
                    # Finalize the current edited minimal cue into a playable cue (one TRACK per FILE)
                    $cuePath = $currentFile.FullName
                    # If the cue already contains TRACK lines, warn first
                    try {
                        $rawLines = Get-Content -LiteralPath $cuePath -ErrorAction Stop | ForEach-Object { ($_ -as [string]).Trim() }
                    }
                    catch {
                        Write-Warning "Cannot read cue file to finalize: $($cuePath) : $($_.Exception.Message)"
                        continue
                    }

                    if ($rawLines -match '(?i)^\s*TRACK\s+\d+') {
                        $ok = Read-OneKey "Cue already contains TRACK entries. Overwrite and regenerate? [y/N] "
                        if ($ok -notmatch '^[Yy]') { Write-Host "Skipped finalize."; continue }
                    }

                    # If helper not available, attempt to dot-source it
                    if (-not (Get-Command -Name Complete-CueFromEditedFile -ErrorAction SilentlyContinue)) {
                        $helper = Join-Path $PSScriptRoot '..\Lib\FinalizeCue.ps1'
                        if (Test-Path $helper) { . $helper } else {
                            Write-Warning "Finalizer helper not found: $helper. Cannot complete cue."
                            continue
                        }
                    }

                    # Confirm for single-file cues (since automatic splitting is not applied)
                    $fileCount = (($rawLines | Where-Object { $_ -match '(?i)^\s*FILE\s+' }) | Measure-Object).Count
                    if ($fileCount -eq 1) {
                        $ok = Read-OneKey "Cue references a single audio file. Do you want to create a single-TRACK cue now? [y/N] "
                        if ($ok -notmatch '^[Yy]') { Write-Host "Skipped finalize for single-file cue."; continue }
                    }

                    # Confirm overwrite of the cue (backup will be created automatically)
                    $confirm = Read-OneKey "Create finalized playable cue (backups saved) for '$([System.IO.Path]::GetFileName($cuePath))'? [Y/n] "
                    if ($confirm -match '^[Nn]') { Write-Host "Cancelled finalize."; continue }

                    try {
                        $r = Complete-CueFromEditedFile -CuePath $cuePath -Overwrite
                        Write-Host "Finalized cue: $($r.CuePath) (backup: $($r.Backup))" -ForegroundColor Green
                        # Offer to open the file for review/editing
                        $open = Read-OneKey "Open finalized cue now? [Y/n] "
                        if ($open -notmatch '^[Nn]') { try { Invoke-Item $r.CuePath } catch { Invoke-Item $r.CuePath } }
                    }
                    catch {
                        Write-Warning "Failed to finalize cue: $($_.Exception.Message)"
                    }

                    # re-analyze the file so UI updates status on next loop iteration
                    continue
                }


                'D' {
                    $confirmPrompt = "Are you sure you want to delete '$($currentFile.Name)'? [y/N] "
                    $confirmChoice = $null
                    if ($env:CUEFIXER_TEST_CHOICE) { $confirmChoice = $env:CUEFIXER_TEST_CONFIRM }
                    if (-not $confirmChoice) { try { $confirmChoice = Read-OneKey $confirmPrompt } catch { $confirmChoice = Read-Host $confirmPrompt } }
                    $confirmStr = if ($null -eq $confirmChoice) { '' } else { [string]$confirmChoice }
                    $confirmStr = $confirmStr.ToUpperInvariant()
                    if ($confirmStr -eq 'Y' -or $confirmStr -eq 'YES') {
                        try {
                            $ts = Get-Date -Format 'yyyyMMddHHmmss'
                            $backupPath = "$($currentFile.FullName).deleted.$ts.bak"
                            Move-Item -LiteralPath $currentFile.FullName -Destination $backupPath -ErrorAction Stop
                            Write-Host "Deleted (moved to): $backupPath" -ForegroundColor Yellow
                            $null = $flatFiles.RemoveAt($pos)
                            $totalFiles = $flatFiles.Count
                            if ($totalFiles -eq 0) { Write-Host "No files remaining." -ForegroundColor DarkCyan; $done = $true; break }
                            if ($pos -ge $totalFiles) { $pos = $totalFiles - 1 }
                            continue
                        }
                        catch { Write-Warning "Failed to delete/move file: $($_.Exception.Message)"; continue }
                    }
                    else { Write-Verbose "Delete cancelled for $($currentFile.Name)."; continue }
                }
                default { Write-Verbose "❓ Invalid choice. Please try again..."; continue }
            }
        } # end while interactive
        # end of interactive logic
    } # end end{}
} # end function
# function Invoke-InteractiveFixImpl {
#     [CmdletBinding()]
#      param(
#         # Accept objects from the pipeline (FileInfo or fileinfo-like PSCustomObject)
#         [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
#         [object]$CueFiles,

#         # Backwards-compatible named parameter for callers that pass an ArrayList
#         [Parameter(Mandatory = $false)]
#         [System.Collections.ArrayList]$CueFilesCollection,

#         [switch]$FullCueLeft
#     )

#     begin {
#         # accumulator ArrayList used for the interactive logic
#         $cueList = New-Object System.Collections.ArrayList

#         # Tracing (write JSON events when CUEFIXER_TRACE=1)
#         $traceEnabled = $false
#         if ($env:CUEFIXER_TRACE -eq '1') {
#             $traceEnabled = $true
#             $logPath = Join-Path $env:TEMP 'cuefixer-interactive-log.json'
#             if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
#             function Write-TraceEvent { param($obj) if ($traceEnabled) { $obj | ConvertTo-Json -Depth 6 | Add-Content -LiteralPath $logPath } }
#         }

#         # If the caller supplied -CueFiles as a named parameter (e.g. Invoke-InteractiveFixImpl -CueFiles $alist),
#         # coerce that value into the accumulator right away. This covers both single objects and enumerable collections.
#         if ($PSBoundParameters.ContainsKey('CueFiles') -and $null -ne $CueFiles) {
#             if ($CueFiles -is [System.Collections.IEnumerable] -and -not ($CueFiles -is [string])) {
#                 foreach ($item in $CueFiles) { [void]$cueList.Add($item) }
#             } else {
#                 [void]$cueList.Add($CueFiles)
#             }
#         }
#         # DO NOT return here — we must allow process{} (pipeline items) and end{} (named collection param) to run.
#     }

#     process {
#          # If caller provided a named collection parameter, we'll handle it in End.
#         # Here we only handle pipeline-bound input (single object per process invocation).
#          # Collect pipeline-bound items (invoked once per pipeline object)
#         if ($null -ne $CueFiles) {
#             if ($CueFiles -is [System.Collections.IEnumerable] -and -not ($CueFiles -is [string])) {
#                 foreach ($item in $CueFiles) { [void]$cueList.Add($item) }
#             } else {
#                 [void]$cueList.Add($CueFiles)
#             }
#         }ief startup pause to allow shells to settle and avoid immediately consuming leftover keypresses
#         #Start-Sleep -Milliseconds 150
#         # Convert grouped folders into an indexable array to allow cross-folder navigation
#         # Normalize input into groups of FileInfo objects grouped by folder so we can index across folders
#         if ($cueList -and $cueList.Count -gt 0) {
#             $first = $cueList[0]

#             # If caller already passed GroupInfo-like objects (Group + Name), use them as-is
#             if ($first -is [Microsoft.PowerShell.Commands.GroupInfo] -or
#                 ($first.PSObject.Properties['Group'] -and $first.PSObject.Properties['Name'])) {
#                 $folders = [System.Collections.ArrayList]$CueFiles
#             }
#             else {
#                 $files = New-Object System.Collections.ArrayList
#                 foreach ($item in $cueList) {
#                     if ($null -eq $item) { continue }

#                     if ($item -is [System.IO.FileInfo]) {
#                         [void]$files.Add($item)
#                         continue
#                     }

#                     try {
#                         $fi = Get-Item -LiteralPath $item -ErrorAction Stop
#                         if ($fi -is [System.IO.FileInfo]) {
#                             [void]$files.Add($fi)
#                         }
#                     }
#                     catch {
#                         # ignore items that can't be resolved to files
#                     }
#                 }

#                 if ($files.Count -gt 0) {
#                     $folders = $files | Group-Object -Property DirectoryName | Sort-Object Name
#                 }
#                 else {
#                     $folders = @()
#                 }
#             }
#         }
#         else {
#             $folders = @()
#         }
#         if (-not $folders -or $folders.Count -eq 0) { return }

#         $folderCount = $folders.Count
#         # Build a flat list of files with folder/file indices so navigation is simple and reliable
#         $flatFiles = New-Object System.Collections.ArrayList
#         for ($fi = 0; $fi -lt $folders.Count; $fi++) {
#             $grp = $folders[$fi]
#             $files = $grp.Group
#             for ($fj = 0; $fj -lt $files.Count; $fj++) {
#                 $obj = [PSCustomObject]@{
#                     FolderIndex = $fi
#                     FileIndex   = $fj
#                     FolderPath  = $grp.Name
#                     FileObj     = $files[$fj]
#                 }
#                 [void]$flatFiles.Add($obj)
#             }
#         }

#         if ($flatFiles.Count -eq 0) { return }

#         $totalFiles = $flatFiles.Count
#         $pos = 0
#         $done = $false

#         # Persistent one-line help banner for keyboard shortcuts
#         Write-Host "Navigation: Left/Right = Prev/Next • Home/End = First/Last • A=Apply • S/Enter=Skip • D=Delete • E=Edit • P=Play • R=Retry • Q=Quit" -ForegroundColor DarkCyan

#         # If standard input is redirected (for example when run from a non-interactive host),
#         # we should not silently auto-advance through files. Detect this and bail with a helpful
#         # message so the caller knows to run in an interactive terminal (or use -PreviewOnly).
#         try {
#             $isInputRedirected = [System.Console]::IsInputRedirected
#         }
#         catch {
#             $isInputRedirected = $false
#         }
#         if ($isInputRedirected -and -not $env:CUEFIXER_TEST_CHOICE) {
#             Write-Warning "Interactive input appears to be redirected or unavailable. Run this command in an interactive terminal (pwsh) or use -PreviewOnly. Aborting interactive session."
#             return
#         }

#         # single-key helper (already defined in earlier branch if present); re-use if available
#         if (-not (Get-Command -Name Read-OneKey -ErrorAction SilentlyContinue)) {
#             function Read-OneKey {
#                 param([string]$Prompt)
            
#                 # Map common virtual key codes to tokens
#                 function Map-VirtualKey {
#                     param([int]$vk)
#                     switch ($vk) {
#                         37 { return 'LEFT' }    # VK_LEFT
#                         39 { return 'RIGHT' }   # VK_RIGHT
#                         36 { return 'HOME' }    # VK_HOME
#                         35 { return 'END' }     # VK_END
#                         13 { return '' }        # Enter -> Next (empty token)
#                         27 { return 'ESC' }     # Escape
#                         default { return $null }
#                     }
#                 }
            
#                 # Optional debug: set this env var to '1' to see raw key info
#                 $debugRawKeys = ($env:CUEFIXER_DEBUG_RAWKEYS -in @('1', 'true', 'True'))
            
#                 # Try System.Console first (native console path)
#                 try {
#                     if ([System.Console]) {
#                         $canCheck = $false
#                         try { $canCheck = [System.Console]::KeyAvailable -is [bool] } catch { $canCheck = $false }
#                         if ($canCheck -and [System.Console]::KeyAvailable) {
#                             Write-Host $Prompt -NoNewline
#                             $cki = [System.Console]::ReadKey($true)
#                             Write-Host ''
#                             switch ($cki.Key) {
#                                 'LeftArrow' { return 'LEFT' }
#                                 'RightArrow' { return 'RIGHT' }
#                                 'Home' { return 'HOME' }
#                                 'End' { return 'END' }
#                                 'Enter' { return '' }
#                                 default { return [string]$cki.KeyChar }
#                             }
#                         }
#                     }
#                 }
#                 catch {
#                     # fall through to RawUI branch
#                 }
            
#                 # Fallback to Host.UI.RawUI (works in many hosts, including PS Core)
#                 try {
#                     $raw = $Host.UI.RawUI
#                     if ($raw -and $raw.GetType()) {
#                         Write-Host $Prompt -NoNewline
#                         while ($true) {
#                             $keyInfo = $raw.ReadKey('NoEcho,IncludeKeyDown')
            
#                             if ($debugRawKeys) {
#                                 # show numeric char code, VirtualKeyCode and Character (visible)
#                                 $charCode = if ($keyInfo.Character) { [int][char]$keyInfo.Character } else { -1 }
#                                 Write-Host "`nDEBUG: CharCode=$charCode Char='$(($keyInfo.Character))' VK=$($keyInfo.VirtualKeyCode)"
#                             }
            
#                             # 1) If Character is ESC (27) -> try to consume CSI/escape sequences (ESC [ ...)
#                             $charCode = if ($keyInfo.Character) { [int][char]$keyInfo.Character } else { -1 }
#                             if ($charCode -eq 27) {
#                                 # try to read following bytes to decode CSI sequences (non-blocking-ish)
#                                 try {
#                                     # read next up to 3 chars quickly (Adjustable)
#                                     $seq = ''
#                                     for ($j = 0; $j -lt 3; $j++) {
#                                         $k = $raw.ReadKey('NoEcho,IncludeKeyDown')
#                                         if ($k -and -not [string]::IsNullOrEmpty($k.Character)) { $seq += [string]$k.Character }
#                                         else { $seq += '' }
#                                     }
#                                     if ($debugRawKeys) { Write-Host "DEBUG: ESC seq='$seq'" }
#                                     # CSI sequences like "[D", "[C", "[A", "[B" map to arrows
#                                     if ($seq.StartsWith('[')) {
#                                         switch ($seq.Substring(0, 2)) {
#                                             '[D' { Write-Host ''; return 'LEFT' }
#                                             '[C' { Write-Host ''; return 'RIGHT' }
#                                             '[A' { Write-Host ''; return 'UP' }
#                                             '[B' { Write-Host ''; return 'DOWN' }
#                                         }
#                                     }
#                                     # Unknown escape -> return ESC
#                                     Write-Host ''
#                                     return 'ESC'
#                                 }
#                                 catch {
#                                     Write-Host ''
#                                     return 'ESC'
#                                 }
#                             }
            
#                             # 2) Try VirtualKeyCode mapping (covers many Windows hosts)
#                             $vk = 0
#                             try { $vk = [int]$keyInfo.VirtualKeyCode } catch { $vk = 0 }
#                             $mapped = $null
#                             if ($vk -ne 0) { $mapped = Map-VirtualKey -vk $vk }
            
#                             if ($mapped -ne $null) {
#                                 Write-Host ''
#                                 return $mapped
#                             }
            
#                             # 3) If Character is printable (non-control), return it (with '<'/'>' mapping)
#                             if (-not [string]::IsNullOrEmpty($keyInfo.Character) -and -not [char]::IsControl($keyInfo.Character)) {
#                                 Write-Host ''
#                                 $ch = [string]$keyInfo.Character
#                                 switch ($ch) {
#                                     '<' { return 'LEFT' }
#                                     '>' { return 'RIGHT' }
#                                     default { return $ch }
#                                 }
#                             }
            
#                             # If we reach here, this keypress had neither printable char nor known VK mapping.
#                             # Loop and wait for the next keypress.
#                         }
#                     }
#                 }
#                 catch {
#                     # fall through to final fallback
#                 }
            
#                 # Last-resort fallback: drain pending keys and ask Read-Host
#                 Clear-KeyboardBuffer
#                 return Read-Host $Prompt
#             }
#         }

#         while (-not $done) {
#             if ($pos -lt 0) { $pos = 0 }
#             if ($pos -ge $totalFiles) { break }

#             $entry = $flatFiles[$pos]
#             $folderIndex = $entry.FolderIndex
#             $fileIndex = $entry.FileIndex
#             $currentFile = $entry.FileObj
#             $folderPath = $entry.FolderPath
#             $filesInFolder = $folders[$folderIndex].Group
#             $fileCount = $filesInFolder.Count

#             # Respect CUEFIXER_NO_CLEAR to allow 'ever-growing' overview output when desired
#             if (-not ($env:CUEFIXER_NO_CLEAR -in @('1', 'true', 'True'))) { Clear-Host }
#             # Visible folder header so the user always sees which folder/album is being previewed
#             Write-Host "`n📁 Folder: $folderPath" -ForegroundColor Cyan
#             Write-Host "Found $($filesInFolder.Count) .cue file(s):" -ForegroundColor DarkCyan
#             $filesInFolder | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor DarkGray }

#             # Analyze the current file only
#             $results = @( Get-CueAuditCore -CueFilePath $currentFile.FullName )
#             if ($traceEnabled) { Write-TraceEvent @{ Event = 'Preview'; Folder = $folderPath; File = $currentFile.Name } }

#             Write-Verbose "`n🧪 Previewing changes (DryRun) for $($currentFile.Name)..."
#             # Render side-by-side cue vs audio files to help the user decide
#             try {
#                 # Allow disabling the interactive per-file preview via env var for problematic hosts
#                 if ($env:CUEFIXER_INTERACTIVE_PREVIEW -eq '0') {
#                     Write-Host "(Interactive preview disabled; set CUEFIXER_INTERACTIVE_PREVIEW=1 to enable)" -ForegroundColor DarkYellow
#                 }
#                 else {
#                    # Parameter takes precedence; otherwise fall back to environment variable for compatibility
#                     $useFullLeft = if ($FullCueLeft.IsPresent) { $true } else { $env:CUEFIXER_FULLCUELEFT -in @('1','true','True') }
#                     Show-CueAudioSideBySide -CueFilePath $currentFile.FullName -FolderPath $folderPath -FullCueLeft:($useFullLeft)
#                   }
#             }
#             catch {
#                 Write-Verbose "Show-CueAudioSideBySide failed: $_"
#             }

#             # Show only the relevant view to reduce noise
#             $res = $results[0]
#             switch ($res.Status) {
#                 'Fixable' { Show-Fixable   -Results $results -DryRun }
#                 'Unfixable' { Show-Unfixable -Results $results }
#                 default { Write-Verbose "No fixes for $($res.Path)" }
#             }

#             # Visual status prompt: File X/Y in Folder N/M
#             $statusLine = "File $($fileIndex + 1)/$fileCount in Folder $($folderIndex + 1)/$folderCount"

#             # Support non-interactive tests via CUEFIXER_TEST_CHOICE environment variable
#             if ($env:CUEFIXER_TEST_CHOICE) {
#                 $choice = $env:CUEFIXER_TEST_CHOICE
#             }
#             else {
#                 $choice = Read-OneKey "`n$statusLine -[A]pply [E]dit  [O]pen folder  [P]lay  [D]elete  [Q]uit  [R]etry  (Enter = Next, Left/Right = Prev/Next, Home = First, End = Last) "
#             }

#             if ($traceEnabled) { Write-TraceEvent @{ Event = 'Prompt'; Folder = $folderPath; File = $currentFile.Name; Choice = $choice } }

#             # Normalize choice to string and uppercase to avoid System.Char issues
#             $selKey = if ($null -eq $choice) { '' } else { [string]$choice }
#             $selKey = $selKey.ToUpperInvariant()

#             switch ($selKey) {
#                 # Next file --------------------------------------------------------
#                 '' {
#                     Write-Verbose "⏭️ Next file..."
#                     $pos = ($pos + 1) % $totalFiles
#                     continue
#                 }

#                 'RIGHT' {
#                     Write-Verbose "⏭️ Quick next (Right arrow)..."
#                     $pos = ($pos + 1) % $totalFiles
#                     continue
#                 }

#                 # Prev file (wrap to previous) ----------------------------------
#                 'LEFT' {
#                     Write-Verbose "⏮️ Moving to previous file (Left arrow)..."
#                     $pos = ($pos - 1 + $totalFiles) % $totalFiles
#                     continue
#                 }

#                 'HOME' {
#                     Write-Verbose "⏮️ Jump to first file (Home)..."
#                     $pos = 0
#                     continue
#                 }

#                 'END' {
#                     Write-Verbose "⏭️ Jump to last file (End)..."
#                     $pos = ($totalFiles - 1)
#                     continue
#                 }

#                 'O' {
#                     if ($traceEnabled) { Write-TraceEvent @{ Event = 'Branch'; Folder = $folderPath; File = $currentFile.Name; Action = 'OpenFolder' } }
#                     $openPath = (Split-Path -Path $currentFile.FullName -Parent)
#                     try { Start-Process -FilePath 'explorer.exe' -ArgumentList ("`"$openPath`"") -ErrorAction Stop } catch { Write-Verbose "Failed to open folder: $($_.Exception.Message)" }
#                     continue
#                 }

#                 'E' {
#                     if ($traceEnabled) { Write-TraceEvent @{ Event = 'Branch'; Folder = $folderPath; File = $currentFile.Name; Action = 'Edit' } }
#                     Write-Verbose "📝 Opening cue file in default editor: $($currentFile.FullName)"
#                     Open-InEditor $currentFile.FullName
#                     # Ensure we pause after returning from the editor so the user can finish edits
#                     try {
#                         # Prompt user to press any key to continue
#                         Read-OneKey "Press any key when finished editing to continue... " | Out-Null
#                     }
#                     catch {
#                         # If Read-OneKey isn't available for some reason, fall back to Read-Host
#                         Read-Host "Press Enter when finished editing to continue..." | Out-Null
#                     }
#                     continue
#                 }

#                 'P' {
#                     if ($traceEnabled) { Write-TraceEvent @{ Event = 'Branch'; Folder = $folderPath; File = $currentFile.Name; Action = 'Play' } }
#                     Write-Verbose "🎵 Playing cue file: $($currentFile.FullName)"
#                     Start-Process $currentFile.FullName
#                     continue
#                 }

#                 'Q' { Write-Verbose "👋 Quitting interactive."; $done = $true; break }

#                 'R' {
#                     if ($traceEnabled) { Write-TraceEvent @{ Event = 'Branch'; Folder = $folderPath; File = $currentFile.Name; Action = 'Retry' } }
#                     Write-Verbose "🔁 Re-analyzing $($currentFile.Name)..."
#                     # re-analyze (loop will re-run)
#                     continue
#                 }
#                 'A' {
#                     if ($traceEnabled) { Write-TraceEvent @{ Event = 'Branch'; Folder = $folderPath; File = $currentFile.Name; Action = 'Apply' } }
#                     Write-Verbose "⚙️ Applying fixes to $($currentFile.Name)..."
#                     try {
#                         $fixResults = @( Invoke-CueFixCore -CueFilePath $currentFile.FullName -WhatIf:$true -ErrorAction Stop )
#                         foreach ($fr in $fixResults) {
#                             if ($fr.Status -eq 'Fixed') {
#                                 Write-Host "✅ Fixed: $($fr.Path)" -ForegroundColor Green
#                             }
#                             elseif ($fr.Status -eq 'Unfixable') {
#                                 Write-Host "❌ Unfixable: $($fr.Path)" -ForegroundColor Red
#                             }
#                             else {
#                                 Write-Host "ℹ️  No changes needed for: $($fr.Path)" -ForegroundColor DarkCyan
#                             }
#                         }
#                     }
#                     catch {
#                         Write-Warning "Failed to apply fixes: $($_.Exception.Message)"
#                     }
#                     # After applying, re-analyze (loop will re-run)

#                     continue
#                 }

#                 'D' {
#                     if ($traceEnabled) { Write-TraceEvent @{ Event = 'Branch'; Folder = $folderPath; File = $currentFile.Name; Action = 'Delete' } }
#                     # Confirm deletion with the user
#                     $confirmPrompt = "Are you sure you want to delete '$($currentFile.Name)'? [y/N] "
#                     $confirmChoice = $null
#                     if ($env:CUEFIXER_TEST_CHOICE) {
#                         # When running tests, allow an override var specifically for confirmations
#                         $confirmChoice = $env:CUEFIXER_TEST_CONFIRM
#                     }
#                     if (-not $confirmChoice) {
#                         try { $confirmChoice = Read-OneKey $confirmPrompt } catch { $confirmChoice = Read-Host $confirmPrompt }
#                     }

#                     $confirmStr = if ($null -eq $confirmChoice) { '' } else { [string]$confirmChoice }
#                     $confirmStr = $confirmStr.ToUpperInvariant()
#                     if ($confirmStr -eq 'Y' -or $confirmStr -eq 'YES') {
#                         if ($traceEnabled) { Write-TraceEvent @{ Event = 'Branch'; Folder = $folderPath; File = $currentFile.Name; Action = 'DeleteConfirmed' } }
#                         try {
#                             $ts = Get-Date -Format 'yyyyMMddHHmmss'
#                             $backupPath = "$($currentFile.FullName).deleted.$ts.bak"
#                             Move-Item -LiteralPath $currentFile.FullName -Destination $backupPath -ErrorAction Stop
#                             Write-Host "Deleted (moved to): $backupPath" -ForegroundColor Yellow
#                             # Remove current entry from flatFiles so navigation continues cleanly
#                             $null = $flatFiles.RemoveAt($pos)
#                             $totalFiles = $flatFiles.Count
#                             if ($totalFiles -eq 0) { Write-Host "No files remaining." -ForegroundColor DarkCyan; $done = $true; break }
#                             if ($pos -ge $totalFiles) { $pos = $totalFiles - 1 }
#                             continue
#                         }
#                         catch {
#                             Write-Warning "Failed to delete/move file: $($_.Exception.Message)"
#                             continue
#                         }
#                     }
#                     else {
#                         if ($traceEnabled) { Write-TraceEvent @{ Event = 'Branch'; Folder = $folderPath; File = $currentFile.Name; Action = 'DeleteCancelled' } }
#                         Write-Verbose "Delete cancelled for $($currentFile.Name)."
#                         continue
#                     }
#                 }

#                 default { Write-Verbose "❓ Invalid choice. Please try again..."; continue }
#             }
#         }
#     }
#     end {
#        #If user passed a named collection via -CueFilesCollection, include its items as well.
#         if ($PSBoundParameters.ContainsKey('CueFilesCollection') -and $null -ne $CueFilesCollection) {
#             if ($CueFilesCollection -is [System.Collections.IEnumerable]) {
#                 foreach ($it in $CueFilesCollection) { [void]$cueList.Add($it) }
#             } else {
#                 [void]$cueList.Add($CueFilesCollection)
#             }
#         }

#         # If no items were collected, bail with a helpful message
#         if (-not $cueList -or $cueList.Count -eq 0) {
#             Write-Warning "No cue files provided to Invoke-InteractiveFixImpl; nothing to do."
#             return
#         }
# }

#         # Back-compat: if prior callers still call with -CueFiles $alist, they can map to CueFilesCollection
#         # (OPTIONAL: if you previously used -CueFiles as the named param, you can either rename CueFilesCollection to CueFiles or
#         #  accept both; above we used two names to avoid breaking parameter binding logic. If your original parameter was -CueFiles,
#         #  change CueFilesCollection to the original name.)

#         # Now $cueList contains all fileinfo-like objects. Continue with the existing implementation,
#         # but replace any original variable that expected the incoming collection with $cueList.

# }








