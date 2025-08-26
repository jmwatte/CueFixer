function Invoke-Heuristic-PreferredExtension {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CueFilePath,
        [Parameter(Mandatory=$true)][string[]]$CueLines,
        [Parameter(Mandatory=$true)][System.IO.FileInfo[]]$CueFolderFiles,
    [Parameter(Mandatory=$false)][hashtable]$Context
    )

    # Contract: return an array of candidate objects: @{ Heuristic=..; Candidate=..; Confidence=..; Reason=.. }
    # small no-op to avoid unused-parameter warnings
    $null = $Context
    # reference CueFilePath to silence analyzer (heuristic doesn't use it directly)
    $null = $CueFilePath
    $ctx = @{}
    if ($null -ne $Context) { $ctx = $Context.Clone() }

    $preferredOrder = @('.flac', '.wav', '.mp3', '.ape')
    if ($ctx.ContainsKey('validAudioExts') -and $ctx.validAudioExts) {
        # honor context order if provided
        $preferredOrder = $ctx.validAudioExts
    }

    $candidates = @()

    foreach ($line in $CueLines) {
        # Very small parser: match FILE "name" <type> or FILE "name.ext" <type>
        if ($line -match 'FILE\s+"(?<name>[^\"]+)"') {
            $name = $Matches['name']
            $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
            $ext = [System.IO.Path]::GetExtension($name)

            if ([string]::IsNullOrEmpty($ext)) {
                # find files in folder matching base name with any audio extensions
                    $fileMatches = $CueFolderFiles | Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $base }
                if ($fileMatches.Count -gt 0) {
                    # order by preferredOrder index
                    $ordered = $fileMatches | Sort-Object { $preferredOrder.IndexOf( ('.' + ($_.Extension.TrimStart('.').ToLower())) ) }
                    # if top candidate extension is found in preferredOrder, propose it with confidence based on uniqueness
                    $top = $ordered | Select-Object -First 1
                    # compute confidence: 0.95 if unique top and preferredOrder places it ahead, else 0.5
                    $confidence = if ($fileMatches.Count -eq 1) { 0.95 } else { 0.5 }
                    $candidatePath = $top.Name
                    $candidates += [pscustomobject]@{
                        Heuristic = 'PreferredExtension'
                        Candidate = $candidatePath
                        Confidence = $confidence
                        Reason = "Preferred extension chosen from available candidates: $(( $fileMatches | ForEach-Object { $_.Name } ) -join ', ')"
                    }
                }
            }
        }
    }

    return $candidates
}









