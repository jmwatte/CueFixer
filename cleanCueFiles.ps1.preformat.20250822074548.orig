param (
	[string]$RootFolder,
	[switch]$Recurse,
	[switch]$AuditOnly,
	[switch]$ShowFixables,
	[switch]$AutoFixFixableOnes,
	[switch]$ShowUnfixableOnes,
	[switch]$SkipGoodOnes,
	[switch]$DryRun,
	[switch]$InteractiveFix
)

$validAudioExts = @(".flac", ".mp3", ".wav", ".aac", ".ogg", ".m4a", ".aiff", ".ape")
$cueStatus = @()



$preferredEditor = "hx"  # Change to "notepad", "code", etc.
<#
.SYNOPSIS
Open a file in the user's preferred editor.

.DESCRIPTION
`Open-InEditor` launches the configured editor (from `$preferredEditor`) for
the supplied file path. The helper is intentionally minimal and used by the
interactive workflow to open cue files for manual editing.

.PARAMETER filePath
Path to the file to open.

.EXAMPLE
Open-InEditor 'C:\Music\Album\album.cue'
#>
function Open-InEditor($filePath) {
	switch ($preferredEditor) {
		"hx" { & hx $filePath }
		"notepad" { notepad $filePath }
		"code" { code $filePath }
		default { Start-Process $filePath }
	}
}
function Fix-CueFileStructure {
	param ([string]$CueFilePath)

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
		if ($line -match $reHeader -and $currentFile -eq $null -and -not $insideTrack) {
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
			# Skip INDEX 00 lines entirely
			continue
		}

		if ($insideTrack -and $line -match $reIndex1) {
			# Force INDEX 01 to be 00:00:00
			$trackBuffer.Add("    INDEX 01 00:00:00") | Out-Null
			if ($currentFile -ne $null) {
				$currentFile.Tracks.Add($trackBuffer) | Out-Null
			}
			$trackBuffer = $null
			$insideTrack = $false
			continue
		}
	}

	# Reconstruct cue file
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
		Copy-Item -LiteralPath $CueFilePath -Destination "$CueFilePath.bak" -Force
		Set-Content -LiteralPath $CueFilePath -Value $fixedText -Encoding UTF8 -Force


		Write-Host "✅ Cue file structure fixed and saved to: $CueFilePath" -ForegroundColor Green
		return $true
	}
 else {
		Write-Host "ℹ️ No structural changes needed for: $CueFilePath" -ForegroundColor DarkGray
		return $false
	}
}
function Invoke-InteractiveFix {
	param ([System.Collections.ArrayList]$cueFiles)

	$groupedByFolder = $cueFiles | Group-Object { $_.DirectoryName }

	foreach ($group in $groupedByFolder) {
		Clear-Host
		$folderPath = $group.Name
		$filesInFolder = $group.Group

		Write-Host "`n📁 Folder: $folderPath" -ForegroundColor Cyan
		Write-Host "Found $($filesInFolder.Count) .cue file(s):"
		$filesInFolder | ForEach-Object { Write-Host "  - $($_.Name)" }

		# Analyze all files in folder
		$results = @()
		foreach ($cue in $filesInFolder) {
			$result = Analyze-CueFile -CueFilePath $cue.FullName
			$results += $result
		}

		# Skip folder if all are clean
		if ((($results | Where-Object { $_.Status -ne 'Clean' }) | Measure-Object).Count -eq 0) {
			Write-Host "✅ All files are clean. Skipping folder..." -ForegroundColor Green
			continue
		}

		do {
			Write-Host "`n🧪 Previewing changes (DryRun)..."
			Show-Fixables -results $results
			Show-Unfixables -results $results

			$choice = Read-Host "`nApply changes? [A] Apply  [S] Skip  [E] Edit  [P] Play  [Q] Quit  [R] Retry (Enter = Skip)"

			switch ($choice.ToUpper()) {
				'' { Write-Host "⏭️ Skipping folder..." -ForegroundColor DarkGray; $retry = $false }
				'S' { Write-Host "⏭️ Skipping folder..." -ForegroundColor DarkGray; $retry = $false }
				'A' {
					Apply-Fixes -results $results
					$retry = $false
				}
				'E' {
					Write-Host "📝 Opening first cue file in default editor..." -ForegroundColor Yellow
					Open-InEditor $filesInFolder[0].FullName
					$retry = $true
				}
				#P lets you play the cuefile
				'P' {
					Write-Host "🎵 Playing first cue file..." -ForegroundColor Yellow
					Start-Process $filesInFolder[0].FullName
					$retry = $true
				}
				'Q' { Write-Host "👋 Quitting script." -ForegroundColor Magenta; exit }
				'R' { Write-Host "🔁 Retrying analysis..." -ForegroundColor Cyan; $retry = $true }
				default { Write-Host "❓ Invalid choice. Please try again..." -ForegroundColor Red; $retry = $true }
			}
		} while ($retry)
	}
}

function Analyze-CueFile {
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
		$line = $cueLines[$i].Trim()
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

function Show-AuditSummary {
	param ($results)
	$clean = ($results | Where-Object { $_.Status -eq 'Clean' }).Count
	$fixable = ($results | Where-Object { $_.Status -eq 'Fixable' }).Count
	$unfixable = ($results | Where-Object { $_.Status -eq 'Unfixable' }).Count

	Write-Host "`n📊 Cue File Audit Summary:"
	Write-Host "✅ Clean: $clean"
	Write-Host "🛠 Fixable: $fixable"
	Write-Host "🛑 Manual Fix Needed: $unfixable"
}

function Show-Fixables {
	param ($results)
	foreach ($cue in $results | Where-Object { $_.Status -eq 'Fixable' }) {
		Write-Host "`n🔍 Processing: $($cue.Path)" -ForegroundColor Cyan
		foreach ($fix in $cue.Fixes) {
			Write-Host "❌ OLD: $($fix.Old)" -ForegroundColor DarkYellow
			Write-Host "✅ NEW: $($fix.New)" -ForegroundColor Yellow
		}
		if ($DryRun) {
			Write-Host "🧪 Dry-run mode — no changes saved." -ForegroundColor DarkCyan
		}
	}
}

<#
.SYNOPSIS
Apply computed fixes to fixable .cue files.

.DESCRIPTION
`Apply-Fixes` takes an array of audit result objects (the output from
`Get-CueAudit`/`Get-CueAuditCore`) and writes proposed fixes to disk for items
marked as `Fixable`. Backups are created via `Save-FileWithBackup` (or manual
copy in legacy flows). Structural fixes are applied first and the file is
re-analyzed before applying content fixes.

.PARAMETER results
An array of audit result objects.

.EXAMPLE
Get-CueAudit -Path . | Apply-Fixes
#>
function Apply-Fixes {
	param ($results)
	foreach ($cue in $results | Where-Object { $_.Status -eq 'Fixable' }) {
		$backupPath = "$($cue.Path).bak"
		Copy-Item -LiteralPath $cue.Path -Destination $backupPath -Force

		# If structural issues were flagged, run the structure fixer first and re-analyze
		if ($cue.NeedsStructureFix) {
			Fix-CueFileStructure -CueFilePath $cue.Path

			# re-analyze so we get updated UpdatedLines/Fixes after structural changes
			$cue = Analyze-CueFile -CueFilePath $cue.Path
			if ($cue.Status -eq 'Unfixable') {
				Write-Host "⚠️ After structure fix the file is unfixable: $($cue.Path)" -ForegroundColor Red
				continue
			}
		}
		foreach ($fix in $cue.Fixes) {
			if ($fix.Old -match 'FILE\s+"(.+?)"\s+(WAVE|MP3|FLAC)' -and -not [System.IO.Path]::GetExtension($matches[1])) {
				$baseName = $matches[1]
				$type = $matches[2]

				$matchedFile = Get-ChildItem -LiteralPath (Split-Path $cue.Path) -File | Where-Object {
					$_.BaseName -ieq $baseName -and ($validAudioExts -contains $_.Extension.ToLower())
				} | Select-Object -First 1

				if ($matchedFile) {
					$correctedLine = "FILE `"$($matchedFile.Name)`" $type"
					$cue.Fixes += [PSCustomObject]@{ Old = $fix.Old; New = $correctedLine }
					$cue.UpdatedLines = $cue.UpdatedLines | ForEach-Object {
						if ($_ -eq $fix.Old) { $correctedLine } else { $_ }
					}
					Write-Host "🛠 Autofixed missing extension in: $($cue.Path)" -ForegroundColor Magenta
				}
				else {
					Write-Host "❌ Could not autofix missing extension for: $($cue.Path)" -ForegroundColor Red
				}
			}
		}
		# Apply content fixes (if any) using the new content fixer and FileIO
		if ($cue.UpdatedLines) {
			$fixResult = Get-CueContentFix -CueFilePath $cue.Path -UpdatedLines $cue.UpdatedLines

			if ($fixResult.Changed) {
				if ($DryRun) {
					Write-Host "🧪 Dry-run: would write fixes to $($cue.Path)" -ForegroundColor DarkCyan
				}
				else {
					# Use centralized IO helper to write file and optionally backup
					Save-FileWithBackup -Path $cue.Path -Content $fixResult.FixedText -Backup:$true | Out-Null
					Write-Host "🔧 Fixed: $($cue.Path)" -ForegroundColor Green
				}
			}
			else {
				Write-Host "ℹ️ No content changes necessary for $($cue.Path)" -ForegroundColor Yellow
			}
		}
		else {
			Write-Host "ℹ️ No content fixes to apply for $($cue.Path)" -ForegroundColor Yellow
		}
	}
}

function Show-Unfixables {
	param ($results)
	foreach ($cue in $results | Where-Object { $_.Status -eq 'Unfixable' }) {
		Write-Host "`n🛑 Manual Fix Needed: $($cue.Path)" -ForegroundColor Red
	}
}

# Scan for .cue files
$cueFiles = if ($Recurse) {
	Get-ChildItem -LiteralPath $RootFolder -Filter *.cue -File -Recurse
}
else {
	Get-ChildItem -LiteralPath $RootFolder -Filter *.cue -File
}

if ($cueFiles.Count -eq 0) {
	Write-Host "📭 No .cue files found in '$RootFolder'" -ForegroundColor Gray
	return
}

# Analyze all cue files
foreach ($cue in $cueFiles) {
	$result = Analyze-CueFile -CueFilePath $cue.FullName
	$cueStatus += $result
}

# Handle output based on parameters
if ($AuditOnly) {
	Show-AuditSummary -results $cueStatus
	return
}

if ($ShowFixables) {
	Show-Fixables -results $cueStatus
}

if ($AutoFixFixableOnes) {
	Apply-Fixes -results $cueStatus
}

if ($ShowUnfixableOnes) {
	Show-Unfixables -results $cueStatus
}

if ($SkipGoodOnes) {
	$cueStatus = $cueStatus | Where-Object { $_.Status -ne 'Clean' }
}

if ($InteractiveFix) {
	Invoke-InteractiveFix -cueFiles $cueFiles
	return
}

