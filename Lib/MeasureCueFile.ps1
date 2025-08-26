function Measure-CueFile {
	param ([string]$CueFilePath)

	$cueFolder = Split-Path $CueFilePath
	$cueLines = Get-Content -LiteralPath $CueFilePath
	$updatedLines = @()
	$changesMade = $false
	$fixes = @()
	$unfixable = $false

	# Structural check (detect misplaced FILE/TRACK/INDEX) — treat as repairable
	$structureErrors = @()
	$needsStructureFix = $false
	$hadFile = $false
	$inTrack = $false
	for ($i = 0; $i -lt $cueLines.Count; $i++) {
		$line = [string]$cueLines[$i]
		$line = $line.Trim()
		if ($line -match '^\s*FILE\s+"(.+?)"\s+\w+\s*$') {
			$hadFile = $true
			$inTrack = $false
			continue
		}
		if ($line -match '^\s*TRACK\s+\d+\s+\w+') {
			if (-not $hadFile) {
				$structureErrors += "TRACK found before any FILE (line $($i+1)): $line"
				$needsStructureFix = $true
			}
			$inTrack = $true
			continue
		}
		if ($line -match '^\s*INDEX\s+\d+\s+') {
			if (-not $inTrack) {
				$structureErrors += "INDEX found outside of TRACK (line $($i+1)): $line"
				$needsStructureFix = $true
			}
			continue
		}
		if ($line -match '^\s*PREGAP\b' -and -not $inTrack) {
			$structureErrors += "PREGAP found outside of TRACK (line $($i+1)): $line"
			$needsStructureFix = $true
		}
	}

	# Per-line content checks (missing audio files are considered truly unfixable)
	foreach ($line in $cueLines) {
		# Ensure we operate on a string (Get-Content can sometimes return a single
		# string which enumerates as characters; cast defensively to avoid
		# calling string methods on System.Char values).
		$line = [string]$line
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
				($_.Name -ieq $filename -or $_.BaseName -ieq $baseName) -and
				($validAudioExts -contains $_.Extension.ToLower())
			} | Select-Object -First 1

			if ($actualFile) {
				if ($validAudioExts -contains $actualFile.Extension.ToLower()) {
					$correctedLine = "FILE `"$($actualFile.Name)`" $type"
					# Normalize both lines for comparison
					$normalizedOld = ($line.Trim().ToLower() -replace '\s+', ' ')
					$normalizedNew = ($correctedLine.Trim().ToLower() -replace '\s+', ' ')
					# Only apply fix if normalized lines differ
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
						# missing audio file -> truly unfixable
						$unfixable = $true
					}
				}
			}
			else {
				# missing audio file -> truly unfixable
				$unfixable = $true
			}
		}

		$updatedLines += $line
	}
# --- Insert: detect essentially-empty CUE and mark for manual cue creation ---
# If there are no FILE/TITLE/TRACK lines, but the folder contains audio files,
# mark it Fixable and add a descriptive proposed "fix" entry (non-destructive).
try {
    $cueRefCount = ($rawLines | Where-Object { $_ -match '^\s*(FILE|TITLE|TRACK)\s+' } | Measure-Object).Count
} catch {
    $cueRefCount = 0
}
if ($cueRefCount -eq 0) {
    $cueDir = Split-Path -Parent $CueFilePath
    # common audio extensions we care about
    $audioExts = @('*.flac','*.wav','*.ape','*.mp3','*.m4a','*.aac','*.ogg')
    $audioFiles = @()
    foreach ($e in $audioExts) {
        $audioFiles += Get-ChildItem -Path $cueDir -File -Filter $e -ErrorAction SilentlyContinue
    }
    $audioFiles = $audioFiles | Sort-Object Name
    if ($audioFiles -and $audioFiles.Count -gt 0) {
        # Mark as Fixable and request a manual/machine-assisted creation step
        $needsStructureFix = $true
        # add an advisory Fix so viewers show something meaningful
        if (-not $Fixes) { $Fixes = @() }
        $Fixes += [PSCustomObject]@{
            Description = 'Create minimal CUE from folder audio files (needs manual verification)'
            Old         = $null
            New         = $null
            Code        = 'MakeCueFile'
        }
        # Add a flag the interactive UI can check
        $NeedsManualCue = $true
        # We intentionally don't attempt to infer track order automatically here.
    } else {
        # No audio files to build from -> probably unfixable
        $unfixable = $true
    }
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