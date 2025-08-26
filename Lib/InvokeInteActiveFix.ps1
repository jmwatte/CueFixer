function Invoke-InteractiveFix {
	param ([System.Collections.ArrayList]$cueFiles)

	# Tracing (write JSON events when CUEFIXER_TRACE=1)
	$traceEnabled = $false
	if ($env:CUEFIXER_TRACE -eq '1') {
		$traceEnabled = $true
		$logPath = Join-Path $env:TEMP 'cuefixer-interactive-log.json'
		if (Test-Path $logPath) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
		function Log-Event { param($obj) if ($traceEnabled) { $obj | ConvertTo-Json -Depth 6 | Add-Content -LiteralPath $logPath } }
	}

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
			$result = Measure-CueFile -CueFilePath $cue.FullName
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

				if ($traceEnabled) { Log-Event @{ Event='Preview'; Folder=$folderPath; ResultsCount=($results.Count) } }

				# Support non-interactive tests via CUEFIXER_TEST_CHOICE environment variable
				if ($env:CUEFIXER_TEST_CHOICE) {
					$choice = $env:CUEFIXER_TEST_CHOICE
				} else {
					Clear-KeyboardBuffer
					$choice = Read-Host "`n[A] Apply  [S] Skip  [E] Edit  [P] Play  [O] Open folder  [Q] Quit  [R] Retry (Enter = Skip)"
				}
				if ($traceEnabled) { Log-Event @{ Event='Prompt'; Folder=$folderPath; Choice=$choice } }

			switch ($choice.ToUpper()) {
				'' { Write-Host "⏭️ Skipping folder..." -ForegroundColor DarkGray; $retry = $false }
				'S' { Write-Host "⏭️ Skipping folder..." -ForegroundColor DarkGray; $retry = $false }
				'A' {
					if ($traceEnabled) { Log-Event @{ Event='Branch'; Folder=$folderPath; Action='Apply' } }
					Apply-Fixes -results $results
					$retry = $false
				}
				'E' {
					if ($traceEnabled) { Log-Event @{ Event='Branch'; Folder=$folderPath; Action='Edit'; File=$filesInFolder[0].FullName } }
					Write-Host "📝 Opening first cue file in default editor..." -ForegroundColor Yellow
					Invoke-Editor $filesInFolder[0].FullName
					$retry = $true
				}
				'O' {
					if ($traceEnabled) { Log-Event @{ Event='Branch'; Folder=$folderPath; Action='OpenFolder' } }
					try { Start-Process -FilePath 'explorer.exe' -ArgumentList ("`"$folderPath`"") -ErrorAction Stop } catch { Write-Verbose "Failed to open folder: $($_.Exception.Message)" }
					$retry = $true
				}
				#P lets you play the cuefile
				'P' {
					if ($traceEnabled) { Log-Event @{ Event='Branch'; Folder=$folderPath; Action='Play'; File=$filesInFolder[0].FullName } }
					Write-Host "🎵 Playing first cue file..." -ForegroundColor Yellow
					Start-Process $filesInFolder[0].FullName
					$retry = $true
				}
				'Q' { Write-Host "👋 Quitting script." -ForegroundColor Magenta; exit }
				'R' { if ($traceEnabled) { Log-Event @{ Event='Branch'; Folder=$folderPath; Action='Retry' } } ; Write-Host "🔁 Retrying analysis..." -ForegroundColor Cyan; $retry = $true }
				default { Write-Host "❓ Invalid choice. Please try again..." -ForegroundColor Red; $retry = $true }
			}
		} while ($retry)
	}
}