function Apply-Fixes {
	param ($results)
	foreach ($cue in $results | Where-Object { $_.Status -eq 'Fixable' }) {
		$backupPath = "$($cue.Path).bak"
		Copy-Item -LiteralPath $cue.Path -Destination $backupPath -Force

		# If structural issues were flagged, run the structure fixer first and re-analyze
		if ($cue.NeedsStructureFix) {
			Fix-CueFileStructure -CueFilePath $cue.Path

			# re-analyze so we get updated UpdatedLines/Fixes after structural changes
			$cue = Measure-CueFile -CueFilePath $cue.Path
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
